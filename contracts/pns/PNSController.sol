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

contract Controller is IController, Context, ManagerOwnable, ERC165, IMulticallable {

    struct Record {
        uint256 origin;
        uint64 expire;
    }

    AggregatorV3Interface public priceFeed;

    using SafeMath for *;
    using StringUtils for *;

    IPNS public _pns;

    mapping(uint256=>Record) records;

    uint256 public BASE_NODE;
    uint256 public MIN_REGISTRATION_DURATION;
    uint256 public MIN_REGISTRATION_LENGTH;
    uint256 public GRACE_PERIOD;
    uint256 public FLAGS;

    constructor(IPNS pns, uint256 _baseNode, uint256[] memory _basePrices, uint256[] memory _rentPrices, address _priceFeed) {
        _pns = pns;
        BASE_NODE = _baseNode;

        MIN_REGISTRATION_LENGTH = 10;
        MIN_REGISTRATION_DURATION = 28 days;
        GRACE_PERIOD = 360 days;
        FLAGS = 7;

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

    function origin(uint256 tokenId) public override view returns(uint256) {
        return records[tokenId].origin;
    }

    // register

    modifier live {
        require((FLAGS & 1) > 0, "invalid op");
        _;
    }

    modifier open {
        require((FLAGS & 2) > 0, "invalid op");
        _;
    }

    modifier redeemable {
        require((FLAGS & 4) > 0, "invalid op");
        _;
    }

    function setContractConfig(uint256 _flags, uint256 _min_length, uint256 _min_duration, uint256 _grace_period, address _price_feed) public onlyRoot {
        FLAGS = _flags;
        MIN_REGISTRATION_LENGTH = _min_length;
        MIN_REGISTRATION_DURATION = _min_duration;
        GRACE_PERIOD = _grace_period;
        priceFeed = AggregatorV3Interface(_price_feed);
        emit ConfigUpdated(_flags);
    }

    function setMetadataBatch(uint256[] calldata tokenIds, Record[] calldata data) public onlyManager {
        require(tokenIds.length == data.length, "invalid data");

        for (uint256 i = 0; i < tokenIds.length; i+=1) {
            uint256 tokenId = tokenIds[i];

            records[tokenId].origin = data[i].origin;
            records[tokenId].expire = data[i].expire;
        }
        emit MetadataUpdated(tokenIds);
    }

    function _register(string calldata name, address to, uint256 duration, uint256 cost) internal returns(uint256) {
        uint256 tokenId = _pns.mintSubdomain(to, BASE_NODE, name);
        require(available(tokenId), "tokenId not available");

        uint256 exp = block.timestamp + duration;
        records[tokenId].expire = uint64(exp);
        records[tokenId].origin = tokenId;

        emit NameRegistered(to, tokenId, cost, exp, name);

        return tokenId;
    }

    function nameRegisterByManager(string calldata name, address to, uint256 duration, uint256 data, uint256[] calldata keyHashes, string[] calldata values) public override live onlyManager returns(uint256) {
        uint256 tokenId = _register(name, to, duration, 0);

        if (keyHashes.length > 0) {
          IResolver(address(_pns)).setManyByHash(keyHashes, values, tokenId);
        }

        if (data & 1 == 1) {
            IResolver(address(_pns)).setName(to, tokenId);
        }

        return tokenId;
    }

    function nameRegister(string calldata name, address to, uint256 duration) public override payable open returns(uint256) {
        uint256 len = name.strlen();
        require(len >= MIN_REGISTRATION_LENGTH, "name too short");
        require(block.timestamp + duration + GRACE_PERIOD > block.timestamp + GRACE_PERIOD, "overflow");
        require(duration >= MIN_REGISTRATION_DURATION, "duration too small");

        uint256 cost = totalRegisterPrice(name, duration);
        require(msg.value >= cost, "insufficient fee");

        uint256 tokenId = _register(name, to, duration, cost);

        payable(_root).transfer(cost);
        if(msg.value > cost) {
            payable(_msgSender()).transfer(msg.value - cost);
        }

        return tokenId;
    }

    function nameRegisterWithConfig(string calldata name, address to, uint256 duration, uint256 data, uint256[] calldata keyHashes, string[] calldata values) public override payable returns(uint256) {
        uint256 tokenId = nameRegister(name, to, duration);

        if (keyHashes.length > 0) {
          IResolver(address(_pns)).setManyByHash(keyHashes, values, tokenId);
        }

        if (data & 1 == 1) {
            IResolver(address(_pns)).setName(to, tokenId);
        }

        return tokenId;
    }

    function nameRedeem(string calldata name, address to, uint256 duration, uint256 deadline, bytes calldata code) public override redeemable returns(uint256) {
        bytes32 label = keccak256(bytes(name));
        bytes memory combined = abi.encodePacked(label, to, duration, deadline);
        require(isManager(recoverKey(keccak256(combined), code)), "code invalid");
        require(block.timestamp < deadline, "deadline mismatched");

        uint256 tokenId = _register(name, to, duration, 0);

        return tokenId;
    }

    function _renew(uint256 id, uint256 duration) internal returns(uint256) {
        require(records[id].origin == id, "not renewable");
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

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (uint8, bytes32, bytes32)
    {
        require(sig.length == 65, "sig invalid");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
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
        require(_pns.isApprovedOrOwner(_msgSender(), tokenId), "not owner nor approved");
        _;
    }

    function mintSubdomain(address to, uint256 tokenId, string calldata name) public virtual override live authorised(tokenId) {
        uint256 originId = records[tokenId].origin;

        uint256 subtokenId = _pns.mintSubdomain(to, tokenId, name);
        records[subtokenId].origin = originId;
    }

    function burn(uint256 tokenId) public virtual live override {
        require((nameExpired(tokenId) && !_pns.bounded(tokenId)) || _root == _msgSender() || _pns.isApprovedOrOwner(_msgSender(), tokenId) || _pns.isApprovedOrOwner(_msgSender(), records[tokenId].origin), "not owner nor approved");
        // require subtokens cleared
        require(records[tokenId].origin != 0, "missing metadata");
        _pns.burn(tokenId);

        uint256 originId = records[tokenId].origin;
        records[tokenId].expire = 0;
        records[tokenId].origin = 0;
    }

    function bound(uint256 tokenId) public override live authorised(tokenId) {
        require(records[tokenId].origin == tokenId || _pns.bounded(records[tokenId].origin), "token origin is not bounded");
        _pns.bound(tokenId);
    }

    // price

    uint256[] private basePrices;
    uint256[] private rentPrices;

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
        return basePrice(name).mul(10 ** 26).div(price) + rentPrice(name, duration).mul(10 ** 26).div(price).div(86400*365);
    }

    function renewPrice(string memory name, uint256 duration) view public override returns(uint256) {
        uint256 price = uint256(getTokenPrice());
        return rentPrice(name, duration).mul(10 ** 26).div(price).div(86400*365);
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

    function multicall(bytes[] calldata data) external override returns(bytes[] memory results) {
        results = new bytes[](data.length);
        for(uint i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success);
            results[i] = result;
        }
        return results;
    }
}
