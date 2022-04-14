// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

import "./IPNS.sol";
import "./IResolver.sol";

import "../utils/RootOwnable.sol";

contract PNS is IPNS, IResolver, ERC721Upgradeable, ManagerOwnableUpgradeable {

    uint256 public FLAGS;

    modifier writable {
        require((FLAGS & 1) > 0, "invalid op");
        _;
    }

    function setContractConfig(uint256 _writable) public onlyRoot {
        FLAGS = _writable;
    }

    function initialize() initializer public override {
      __ERC721_init("PNS", "PNS");
      ManagerOwnableUpgradeable.initialize();
      FLAGS = 1;
    }

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
    
    // todo : reorder modifier and functions
    // todo : is root or manager permission necessary
    modifier authorised(uint256 tokenId) {
        require(_root == _msgSender() || isManager(_msgSender()) || isApprovedOrOwner(_msgSender(), tokenId), "not owner nor approved");
        _;
    }

    function isApprovedOrOwner(address addr, uint256 tokenId) public view override returns(bool) {
        return _isApprovedOrOwner(addr, tokenId);
    }

    // registry

    function mint(address to, uint256 newTokenId) public virtual override onlyRoot {
        _mint(to, newTokenId);
    }

    function mintSubdomain(address to, uint256 tokenId, string calldata name) public virtual override onlyManager returns (uint256) {
        // parent domain owner only
        bytes32 label = keccak256(bytes(name));
        bytes32 subnode = keccak256(abi.encodePacked(tokenId, label));
        uint256 subtokenId = uint256(subnode);
        _mint(to, subtokenId);

        emit NewSubdomain(to, tokenId, subtokenId, name);
        return subtokenId;
    }

    // todo : consider using multicall
    function mintSubdomainBatch(address[] calldata addrs, uint256[] calldata tokenIds, string[] calldata names) public virtual onlyManager {
        for (uint256 i = 0; i < addrs.length; i++) {
            bytes32 label = keccak256(bytes(names[i]));
            bytes32 subnode = keccak256(abi.encodePacked(tokenIds[i], label));
            uint256 subtokenId = uint256(subnode);
            _mint(addrs[i], subtokenId);

            emit NewSubdomain(addrs[i], tokenIds[i], subtokenId, names[i]);
        }
    }

    function burn(uint256 tokenId) public virtual override onlyManager {
        _burn(tokenId);
    }

    // records

    mapping(uint256 => string) private _keys;
    mapping(uint256 => mapping(uint256 => string)) internal _records;
    mapping(address => uint256) private _names;
    mapping(address => mapping(uint256 => uint256)) internal _nft_names;

    function setName(
        uint256 tokenId
    ) external override writable authorised(tokenId) {
        _names[_msgSender()] = tokenId;
        // todo : emit event
    }

    function getName(address addr) public view override returns (uint256) {
        return _names[addr];
    }

    function setNftName(
        address nft,
        uint256 nftTokenId,
        uint256 nameTokenId
    ) external override writable authorised(nameTokenId) {
        // todo : replace IERC721Upgradeable with IERC721
        require(IERC721Upgradeable(nft).ownerOf(nftTokenId) == _msgSender(), 'not token owner');
        _nft_names[nft][nftTokenId] = nameTokenId;
        // todo : emit event
    }

    function getNftName(address nftAddr, uint256 nftTokenId) public view override returns (uint256) {
        return _nft_names[nftAddr][nftTokenId];
        // todo : check nft owner == name owner
    }

    function getKey(uint256 keyHash) public view override returns (string memory) {
        return _keys[keyHash];
    }

    function getKeys(uint256[] calldata hashes) public view override returns (string[] memory values) {
        values = new string[](hashes.length);
        for (uint256 i = 0; i < hashes.length; i++) {
            values[i] = getKey(hashes[i]);
        }
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

    function set(
        string calldata key,
        string calldata value,
        uint256 tokenId
    ) external override writable authorised(tokenId) {
        uint256 keyHash = uint256(keccak256(abi.encodePacked(key)));
        _addKey(keyHash, key);  // todo : redundant
        _set(keyHash, value, tokenId);
    }

    function _set(
        uint256 keyHash,
        string memory value,
        uint256 tokenId
    ) private {
        _records[tokenId][keyHash] = value;
        emit Set(tokenId, keyHash, value);
    }

    function setMany(
        string[] calldata keys,
        string[] calldata values,
        uint256 tokenId
    ) external override writable authorised(tokenId) {
        for (uint256 i = 0; i < keys.length; i++) {
            _set(uint256(keccak256(abi.encodePacked(keys[i]))), values[i], tokenId);
        }
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
        for (uint256 i = 0; i < keyHashes.length; i++) {
            require(_existsKey(keyHashes[i]), 'key not found');
            _set(keyHashes[i], values[i], tokenId);
        }
    }
}
