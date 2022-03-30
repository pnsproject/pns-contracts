// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "../utils/StringUtils.sol";
import "../utils/SafeMath.sol";
import "../utils/RootOwnable.sol";

import "./IPNS.sol";
import "./IController.sol";
import "./IResolver.sol";

contract Controller is IController, Context, ManagerOwnable, ERC165 {

    struct Record {
        uint256 origin;
        uint64 expire;
        uint64 capacity;
        uint64 children;
    }

    AggregatorV3Interface public priceFeed;

    using SafeMath for *;
    using StringUtils for *;

    IPNS public _pns;

    mapping(uint256=>Record) records;

    uint256 public BASE_NODE;
    uint256 public DEFAULT_DOMAIN_CAPACITY;
    uint256 public MIN_REGISTRATION_DURATION;
    uint256 public MIN_REGISTRATION_LENGTH;
    uint256 public GRACE_PERIOD;
    uint256 public FLAGS;

    constructor(IPNS pns, uint256 _baseNode, uint256[] memory _basePrices, uint256[] memory _rentPrices, address _priceFeed) {
        _pns = pns;
        BASE_NODE = _baseNode;

        DEFAULT_DOMAIN_CAPACITY = 20;
        MIN_REGISTRATION_LENGTH = 10;
        MIN_REGISTRATION_DURATION = 28 days;
        GRACE_PERIOD = 360 days;
        FLAGS = 7;
        capacityPrice = 100;

        setPrices(_basePrices, _rentPrices);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IController).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function nameExpired(uint256 tokenId) public view returns(bool) {
        return records[records[tokenId].origin].expire + GRACE_PERIOD < block.timestamp;
    }

    function available(uint256 tokenId) public override view returns(bool) {
        return records[tokenId].origin == 0;
    }

    function expire(uint256 tokenId) public override view returns(uint256) {
        return uint256(records[tokenId].expire);
    }

    function capacity(uint256 tokenId) public override view returns(uint256) {
        return uint256(records[tokenId].capacity);
    }

    function children(uint256 tokenId) public override view returns(uint256) {
        return uint256(records[tokenId].children);
    }

    function origin(uint256 tokenId) public override view returns(uint256) {
        return records[tokenId].origin;
    }

    // register

    modifier live {
        require((FLAGS & 1) > 0, "invalid op");
        _;
    }

    modifier open {
        require((FLAGS & 3) > 0, "invalid op");
        _;
    }

    modifier redeemable {
        require((FLAGS & 5) > 0, "invalid op");
        _;
    }

    function setContractConfig(uint256 _flags, uint256 _min_length, uint256 _min_duration, uint256 _grace_period, uint256 _default_capacity, uint256 _capacity_price, address _price_feed) public live onlyRoot {
        FLAGS = _flags;
        MIN_REGISTRATION_LENGTH = _min_length;
        MIN_REGISTRATION_DURATION = _min_duration;
        GRACE_PERIOD = _grace_period;
        DEFAULT_DOMAIN_CAPACITY = _default_capacity;
        capacityPrice = _capacity_price;
        priceFeed = AggregatorV3Interface(_price_feed);
        emit ConfigUpdated(_flags);
    }

    function setCapacityByManager(uint256 tokenId, uint256 _capacity) public override live onlyManager {
        records[tokenId].capacity = uint64(_capacity);
        emit CapacityUpdated(tokenId, _capacity);
    }

    function setCapacity(uint256 tokenId, uint256 _capacity) public payable override live {
        uint256 cost = getCapacityPrice(_capacity - records[tokenId].capacity);
        require(msg.value >= cost, "insufficient fee");

        payable(_root).transfer(cost);
        if(msg.value > cost) {
            payable(_msgSender()).transfer(msg.value - cost);
        }

        records[tokenId].capacity = uint64(_capacity);
        emit CapacityUpdated(tokenId, _capacity);
    }

    function setMetadataBatch(uint256[] calldata data) public live onlyManager {
        uint256 len = data.length;
        require(len % 5 == 0, "len invalid");

        for (uint256 i = 0; i < len; i+=5) {
            uint256 tokenId = data[i];
            records[tokenId].origin = data[i+1];
            records[tokenId].expire = uint64(data[i+2]);
            records[tokenId].capacity = uint64(data[i+3]);
            records[tokenId].children = uint64(data[i+4]);
        }
        emit MetadataUpdated(data);
    }

    function nameRegisterByManager(string calldata name, address to, uint256 duration) public override live onlyManager returns(uint256) {
        uint256 tokenId = _pns.mintSubdomain(to, BASE_NODE, name);
        require(available(tokenId), "tokenId not available");
        uint256 exp = block.timestamp + duration;
        records[tokenId].expire = uint64(exp);
        records[tokenId].capacity = uint64(DEFAULT_DOMAIN_CAPACITY);
        records[tokenId].origin = tokenId;
        emit NameRegistered(to, tokenId, 0, exp, name);

        return tokenId;
    }

    function nameRegister(string calldata name, address to, uint256 duration) public override payable open returns(uint256) {
        uint256 len = name.strlen();
        require(len >= MIN_REGISTRATION_LENGTH, "name too short");

        require(block.timestamp + duration + GRACE_PERIOD > block.timestamp + GRACE_PERIOD);
        uint256 tokenId = _pns.mintSubdomain(to, BASE_NODE, name);
        require(available(tokenId), "tokenId not available");

        uint256 expr = block.timestamp + duration;
        records[tokenId].expire = uint64(expr);
        records[tokenId].capacity = uint64(DEFAULT_DOMAIN_CAPACITY);
        records[tokenId].origin = tokenId;

        uint256 cost = totalRegisterPrice(name, duration);
        require(duration >= MIN_REGISTRATION_DURATION, "duration too small");
        require(msg.value >= cost, "insufficient fee");

        emit NameRegistered(to, tokenId, cost, expr, name);

        payable(_root).transfer(cost);
        if(msg.value > cost) {
            payable(_msgSender()).transfer(msg.value - cost);
        }

        return tokenId;
    }

    function nameRegisterWithConfig(string calldata name, address to, uint256 duration, uint256[] calldata keyHashes, string[] calldata values) public override payable returns(uint256) {
        uint256 tokenId = nameRegister(name, to, duration);

        if (keyHashes.length > 0) {
          IResolver(address(_pns)).setManyByHash(keyHashes, values, tokenId);
        }

        return tokenId;
    }

    function _renew(uint256 id, uint256 duration) internal returns(uint256) {
        // require(records[id].expire + GRACE_PERIOD >= block.timestamp, "exceed grace period");
        require(records[id].expire + duration + GRACE_PERIOD > block.timestamp + GRACE_PERIOD, "prevent overflow");

        records[id].expire += uint64(duration);
        return records[id].expire;
    }

    // controller methods

    function renew(string calldata name, uint256 duration) external override open payable {
        bytes32 label = keccak256(bytes(name));
        bytes32 subnode = keccak256(abi.encodePacked(BASE_NODE, label));
        uint256 tokenId = uint256(subnode);
        uint256 expireAt = _renew(tokenId, duration);

        uint256 cost = renewPrice(name, duration);
        require(msg.value >= cost, "insufficient fee");

        emit NameRenewed(tokenId, cost, expireAt, name);

        payable(_root).transfer(cost);
        if(msg.value > cost) {
            payable(_msgSender()).transfer(msg.value - cost);
        }
    }

    function renewByManager(string calldata name, uint256 duration) external override live onlyManager {
        bytes32 label = keccak256(bytes(name));
        bytes32 subnode = keccak256(abi.encodePacked(BASE_NODE, label));
        uint256 tokenId = uint256(subnode);
        uint256 expireAt = _renew(tokenId, duration);

        emit NameRenewed(tokenId, 0, expireAt, name);
    }

    // redeem

    function nameRedeem(string calldata name, address to, uint256 duration, bytes calldata code) public override redeemable returns(uint256) {
        bytes32 label = keccak256(bytes(name));
        bytes memory combined = abi.encodePacked(label, to, duration);
        require(isManager(recoverKey(keccak256(combined), code)), "code invalid");

        uint256 tokenId = _pns.mintSubdomain(to, BASE_NODE, name);
        require(available(tokenId), "tokenId not available");

        uint256 exp = block.timestamp + duration;
        records[tokenId].expire = uint64(exp);
        records[tokenId].capacity = uint64(DEFAULT_DOMAIN_CAPACITY);
        records[tokenId].origin = tokenId;

        emit NameRegistered(to, tokenId, 0, exp, name);

        return tokenId;
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function recoverKey(bytes32 datahash, bytes calldata code) public pure returns (address) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = splitSignature(code);

        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", datahash));

        return ecrecover(hash, v, r, s);
    }

    modifier authorised(uint256 tokenId) {
        require(_root == _msgSender() || _pns.isApprovedOrOwner(_msgSender(), tokenId), "not owner nor approved");
        _;
    }

    function mintSubdomain(address to, uint256 tokenId, string calldata name) public virtual override open authorised(tokenId) {
        uint256 originId = records[tokenId].origin;
        require(records[originId].children < records[originId].capacity, "reach subdomain capacity");
        uint256 subtokenId = _pns.mintSubdomain(to, tokenId, name);

        records[originId].children += 1;
        records[subtokenId].origin = originId;

        emit NewSubdomain(to, tokenId, subtokenId, name);
    }

    function burn(uint256 tokenId) public virtual open override {
        require(nameExpired(tokenId) || _root == _msgSender() || _pns.isApprovedOrOwner(_msgSender(), tokenId) || _pns.isApprovedOrOwner(_msgSender(), records[tokenId].origin), "not owner nor approved");
        // require subtokens cleared
        require(records[tokenId].origin != 0, "missing metadata");
        require(records[tokenId].children == 0, "subdomains not cleared");
        _pns.burn(tokenId);

        uint256 originId = records[tokenId].origin;
        if (records[originId].children > 0) {
          records[originId].children -= 1;
        }
        records[tokenId].expire = 0;
        records[tokenId].capacity = 0;
        records[tokenId].origin = 0;
    }

    function burnBatch(uint256[] calldata data) public virtual onlyManager {
        uint256 len = data.length;

        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = data[i];
            uint256 originId = records[tokenId].origin;
            require(originId != 0, "missing metadata");
            require(records[tokenId].children == 0, "subdomains not cleared");
            _pns.burn(tokenId);

            if (records[originId].children > 0) {
              records[originId].children -= 1;
            }
            records[tokenId].expire = 0;
            records[tokenId].capacity = 0;
            records[tokenId].origin = 0;
        }
    }

    // price

    uint256[] private basePrices;
    uint256[] private rentPrices;
    uint256 public capacityPrice;

    function getTokenPrice() public override view returns (int) {
        (, int price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    function getPrices() view public override returns(uint256[] memory, uint256[] memory) {
        return (basePrices, rentPrices);
    }

    function setPrices(uint256[] memory _basePrices, uint256[] memory _rentPrices) public override onlyRoot {
        basePrices = _basePrices;
        rentPrices = _rentPrices;
        emit PriceChanged(_basePrices, _rentPrices);
    }

    function totalRegisterPrice(string memory name, uint256 duration) view public override returns(uint256) {
        uint256 price = uint256(getTokenPrice());
        return (basePrice(name) + rentPrice(name, duration).div(86400*365)).mul(10 ** 26).div(price);
    }

    function renewPrice(string memory name, uint256 duration) view public override returns(uint256) {
        uint256 price = uint256(getTokenPrice());
        return rentPrice(name, duration).mul(10 ** 26).div(price).div(86400*365);
    }

    function getCapacityPrice(uint256 delta) view public returns(uint256) {
        require(delta > 0, "invalid delta");
        uint256 price = uint256(getTokenPrice());
        return delta.mul(capacityPrice).mul(10 ** 24).div(price);
    }

    function basePrice(string memory name) view public override returns(uint256) {
        uint256 len = name.strlen();
        if(len > basePrices.length) {
            len = basePrices.length;
        }
        uint256 price = basePrices[len - 1];

        return price;
    }

    function rentPrice(string memory name, uint256 duration) view public override returns(uint256) {
        uint256 len = name.strlen();
        if(len > rentPrices.length) {
            len = rentPrices.length;
        }
        uint256 price = rentPrices[len - 1].mul(duration);

        return price;
    }

    function withdraw() public override onlyRoot {
        uint256 amount = address(this).balance;

        (bool success, ) = payable(_root).call{value: amount}("");
        require(success, "Failed to send Ether");
    }
}
