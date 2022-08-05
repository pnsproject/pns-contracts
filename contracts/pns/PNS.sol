// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";

import "./IPNS.sol";
import "./IResolver.sol";

import "../utils/RootOwnable.sol";
import "../utils/StringUtils.sol";

contract PNS is IPNS, IResolver, ERC721Upgradeable, ManagerOwnableUpgradeable, ERC2771ContextUpgradeable {
    using StringUtils for *;

    event ConfigUpdated(uint256 flags);

    uint256 public FLAGS;
    uint256 public GRACE_PERIOD;

    modifier writable {
        require((FLAGS & 1) > 0, "invalid op");
        _;
    }

    function setContractConfig(uint256 _writable) public onlyRoot {
        FLAGS = _writable;
        emit ConfigUpdated(_writable);
    }

    // ------------ initializer & constructor
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address forwarder) ERC2771ContextUpgradeable(forwarder) {}

    function initialize() initializer public override {
      __ERC721_init("PNS", "PNS");
      ManagerOwnableUpgradeable.initialize();
      FLAGS = 1;
      GRACE_PERIOD = 360 days;
    }

    // ----------------- override function for ERC2771
    // override function
    function _msgSender() internal view virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }

    // --------------- ERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165Upgradeable, ERC721Upgradeable) returns (bool) {
        return
            interfaceId == type(IPNS).interfaceId || interfaceId == type(IResolver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function exists(uint256 tokenId) public view virtual override returns(bool) {
        return _exists(tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://meta.dot.site/";
    }

    modifier authorised(uint256 tokenId) {
        require(isManager(_msgSender()) || _isApprovedOrOwner(_msgSender(), tokenId), "not owner nor approved");
        _;
    }

    function isApprovedOrOwner(address addr, uint256 tokenId) public view override returns(bool) {
        return _isApprovedOrOwner(addr, tokenId);
    }

    // registry

    function mint(address to, uint256 newTokenId) public virtual override onlyRoot {
        _mint(to, newTokenId);
    }

    function mintSubdomain(address to, uint256 tokenId, string calldata name) public virtual override  authorised(tokenId) returns (uint256) {
        require(name.domainPrefixValid(), "name invalid");

        // parent domain owner only
        bytes32 label = keccak256(bytes(name));
        bytes32 subnode = keccak256(abi.encodePacked(tokenId, label));
        uint256 subtokenId = uint256(subnode);
        _mint(to, subtokenId);

        records[subtokenId].parent = tokenId;
        records[subtokenId].origin = records[tokenId].origin;

        emit NewSubdomain(to, tokenId, subtokenId, name);
        return subtokenId;
    }

    function burn(uint256 tokenId) public virtual override {
        require((nameExpired(tokenId) && !_bounds[tokenId]) || _root == _msgSender() || isApprovedOrOwner(_msgSender(), tokenId) || isApprovedOrOwner(_msgSender(), records[tokenId].origin), "not owner nor approved");
        // require subtokens cleared
        _burn(tokenId);

        _bounds[tokenId] = false;

        records[tokenId].expire = 0;
        records[tokenId].origin = 0;
    }

    // records

    mapping(uint256 => string) private _keys;
    mapping(uint256 => mapping(uint256 => string)) internal _records;
    mapping(address => uint256) private _names;
    mapping(address => mapping(uint256 => uint256)) internal _nft_names;

    function setName(
        address addr,
        uint256 tokenId
    ) external override writable {
        require(isManager(_msgSender()) ||
               (_isApprovedOrOwner(_msgSender(), tokenId) &&
                  (_msgSender() == addr || ownsContract(addr))), "not owner nor approved");

        _names[addr] = tokenId;
        emit SetName(addr, tokenId);
    }

    function ownsContract(address addr) internal view returns (bool) {
        try OwnableUpgradeable(addr).owner() returns (address owner) {
            return owner == _msgSender();
        } catch {
            return false;
        }
    }

    function getNameUnchecked(address addr) public view returns (uint256) {
        return _names[addr];
    }

    // attack vector
    // 1. 'trust-doamin-name' is owner by attacker
    // 2. attacker.setName(attackerWallet, namehash('trust-domain-name'))
    // 3. sell 'trust-domain-name' to victim
    // 4. victim.setName(victimWallet, namehash('trust-domain-name'))
    // 5. victim provide some service, using 'trust-domain-name' as view of victimWallet to receive payment
    // 6. attacker do phishing on victim's service, can use attackerWallet to get payment, because
    //    getName(attackerWallet) will still return namehash('trust-domain-name')
    function getName(address addr) public view override returns (uint256 tokenId) {
        tokenId = getNameUnchecked(addr);

        // return tokenId if any of below condition is valid
        // 1. owner of tokenId is addr
        // 2. tokenId is approved for addr
        if (!_exists(tokenId)) {
            tokenId = 0;
        }
        else if (!_isApprovedOrOwner(addr, tokenId)) {
            tokenId = 0;
        }
    }

    // *USE WITH CAUTION*
    // 1. resolve NFT token to PNS domain is different from resolve wallet/contract to PNS domain
    // 2. NFT token is transferable, wallet is not.
    // 3. when sell NFT token, which show as PNS domain name, *NON-UNIQUE* mapping of
    //    NFT token to PNS domain will cause problem
    // 4. for example, map 2 different value NFT token to same PNS domain
    // 5. when sell NFT, only PNS domain is shown, buyer will not able to distinguish which NFT token
    //    is on sale.
    function setNftName(
        address nftAddr,
        uint256 nftTokenId,
        uint256 tokenId
    ) external override writable authorised(tokenId) {
        address tokenOwner = IERC721Upgradeable(nftAddr).ownerOf(nftTokenId);
        require(tokenOwner == _msgSender() ||
                IERC721Upgradeable(nftAddr).getApproved(nftTokenId) == _msgSender() ||
                IERC721Upgradeable(nftAddr).isApprovedForAll(tokenOwner, _msgSender()) , 'not owner nor approved');
        _nft_names[nftAddr][nftTokenId] = tokenId;
        emit SetNftName(nftAddr, nftTokenId, tokenId);
    }

    function getNftName(address nftAddr, uint256 nftTokenId) public view override returns (uint256) {
        return _nft_names[nftAddr][nftTokenId];
    }

    function getKey(uint256 keyHash) public view override returns (string memory) {
        return _keys[keyHash];
    }

    function addKeys(string[] memory keys) external override {
        for (uint256 i = 0; i < keys.length; i++) {
            string memory key = keys[i];
            _addKey(uint256(keccak256(abi.encodePacked(key))), key);
        }
    }

    function _existsKey(uint256 keyHash) internal view returns (bool) {
        return bytes(_keys[keyHash]).length > 0;
    }

    function _addKey(uint256 keyHash, string memory key) internal {
        if (!_existsKey(keyHash)) {
            _keys[keyHash] = key;
            emit NewKey(key, key);
        }
    }

    function get(string calldata key, uint256 tokenId) external view override returns (string memory value) {
        value = _get(key, tokenId);
    }

    function _get(string calldata key, uint256 tokenId) private view returns (string memory) {
        return _get(uint256(keccak256(abi.encodePacked(key))), tokenId);
    }

    function _get(uint256 keyHash, uint256 tokenId) private view returns (string memory) {
        return _records[tokenId][keyHash];
    }

    function getMany(string[] calldata keys, uint256 tokenId) external view override returns (string[] memory values) {
        values = new string[](keys.length);
        for (uint256 i = 0; i < keys.length; i++) {
            values[i] = _get(keys[i], tokenId);
        }
    }

    function getByHash(uint256 keyHash, uint256 tokenId)
        external
        view
        override
        returns (string memory value)
    {
        value = _getByHash(keyHash, tokenId);
    }

    function _getByHash(uint256 keyHash, uint256 tokenId)
        private
        view
        returns (string memory value)
    {
        value = _get(keyHash, tokenId);
    }

    function getManyByHash(uint256[] calldata keyHashes, uint256 tokenId)
        external
        view
        override
        returns (string[] memory values)
    {
        values = new string[](keyHashes.length);
        for (uint256 i = 0; i < keyHashes.length; i++) {
            values[i] = _getByHash(keyHashes[i], tokenId);
        }
    }

    function _set(
        uint256 keyHash,
        string calldata value,
        uint256 tokenId
    ) private {
        _records[tokenId][keyHash] = value;
        emit Set(tokenId, keyHash, value);
    }

    function setByHash(
        uint256 keyHash,
        string calldata value,
        uint256 tokenId
    ) external override writable authorised(tokenId) {
        require(_existsKey(keyHash), 'key not found');
        _set(keyHash, value, tokenId);
    }

    function setManyByHash(
        uint256[] calldata keyHashes,
        string[] calldata values,
        uint256 tokenId
    ) external override writable authorised(tokenId) {
        require(keyHashes.length == values.length, "invalid data");

        for (uint256 i = 0; i < keyHashes.length; i++) {
            require(_existsKey(keyHashes[i]), 'key not found');
            _set(keyHashes[i], values[i], tokenId);
        }
    }

    mapping(uint256 => mapping(uint256 => uint256)) internal _links;

    function getlinks(uint256 source, uint256[] memory targets) external view override returns (uint256[] memory values) {
        values = new uint256[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
             values[i] = _links[source][targets[i]];
        }
    }

    function getlink(uint256 source, uint256 target) external view override returns (uint256) {
        return _links[source][target];
    }

    function setlink(
        uint256 source,
        uint256 target,
        uint256 value
    ) external override writable authorised(source) {
        _links[source][target] = value;
        emit SetLink(source, target, value);
    }

    function setlinks(
        uint256 source,
        uint256[] calldata targets,
        uint256[] calldata values
    ) external override writable authorised(source) {
        require(targets.length == values.length, "invalid data");

        for (uint256 i = 0; i < targets.length; i++) {
            uint256 target = targets[i];
            uint256 value = values[i];
            _links[source][target] = value;
            emit SetLink(source, target, value);
        }
    }

    mapping(uint256 => bool) internal _bounds;

    function bounded(uint256 tokenId) external view override returns (bool) {
        return _bounds[tokenId];
    }

    function bound(uint256 tokenId) public override authorised(tokenId) {
        require(records[tokenId].origin == tokenId || _bounds[records[tokenId].origin], "token origin is not bounded");
        _bounds[tokenId] = true;
    }

    function _beforeTokenTransfer(
        address /* _from */,
        address to,
        uint256 tokenId
    ) internal view override {
        if (to != address(0)) {
          require(!_bounds[tokenId], "token bounded");
        }
    }


    struct Record {
        uint256 origin;
        uint256 parent;
        uint64 expire;
    }

    mapping(uint256=>Record) records;

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

    function parent(uint256 tokenId) public override view returns(uint256) {
        return records[tokenId].parent;
    }

    event MetadataUpdated(uint256[] data);
    // todo

    function setMetadataBatch(uint256[] calldata tokenIds, Record[] calldata data) public onlyManager {
        require(tokenIds.length == data.length, "invalid data");

        for (uint256 i = 0; i < tokenIds.length; i+=1) {
            uint256 tokenId = tokenIds[i];

            records[tokenId].origin = data[i].origin;
            records[tokenId].parent = data[i].parent;
            records[tokenId].expire = data[i].expire;
        }
        emit MetadataUpdated(tokenIds);
    }

    function register(string calldata name, address to, uint64 duration, uint256 baseNode) public override onlyManager returns(uint256) {
        // require(name.domainPreifxValid()); // skip due this will check by mintSubdomain
        uint256 tokenId = mintSubdomain(to, baseNode, name);
        require(available(tokenId), "tokenId not available");

        uint256 exp = block.timestamp + duration;
        records[tokenId].expire = uint64(exp);
        records[tokenId].origin = tokenId;
        records[tokenId].parent = tokenId;

        return tokenId;
    }

    function renew(uint256 id, uint64 duration) public override onlyManager returns(uint256) {
        require(records[id].origin == id, "not renewable");
        require(records[id].expire + duration + GRACE_PERIOD > records[id].expire + GRACE_PERIOD, "prevent overflow");
        // todo
        records[id].expire += duration;
        return records[id].expire;
    }
}
