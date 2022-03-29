// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./IResolver.sol";
import "./IPNS.sol";

contract PNSResolver is IResolver {

    IPNS public _pns;
    mapping(uint256 => string) private _keys;
    mapping(uint256 => mapping(uint256 => string)) internal _records;
    mapping(address => uint256) private _names;
    mapping(address => mapping(uint256 => uint256)) internal _nft_names;

    constructor(IPNS pns) {
        _pns = pns;
    }

    modifier authorised(uint256 tokenId) {
        // todo : check tokenId expire
        require(_pns.isApprovedOrOwner(msg.sender, tokenId), "not owner nor approved");
        _;
    }

    function setName(
        uint256 tokenId
    ) external override authorised(tokenId) {
        // todo : verify addr ownership
        _names[msg.sender] = tokenId;
    }

    function getName(address addr) public view override returns (uint256) {
        return _names[addr];
    }

    function setNftName(
        address nft,
        uint256 nftTokenId,
        uint256 nameTokenId
    ) external override authorised(nameTokenId) {
        require(IERC721(nft).ownerOf(nftTokenId) == msg.sender, 'not owner');
        _nft_names[nft][nftTokenId] = nameTokenId;
    }

    function getNftName(address nftAddr, uint256 nftTokenId) public view override returns (uint256) {
        return _nft_names[nftAddr][nftTokenId];
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
    ) external override authorised(tokenId) {
        uint256 keyHash = uint256(keccak256(abi.encodePacked(key)));
        _addKey(keyHash, key);
        _set(keyHash, key, value, tokenId);
    }

    function _set(
        uint256 keyHash,
        string memory key,
        string memory value,
        uint256 tokenId
    ) private {
        if (bytes(_records[tokenId][keyHash]).length == 0) {
            emit NewKey(tokenId, key, key);
        }
        // todo: remove key param

        _records[tokenId][keyHash] = value;
        emit Set(tokenId, key, value, key, value);
    }

    function _set(
        string calldata key,
        string calldata value,
        uint256 tokenId
    ) internal {
        uint256 keyHash = uint256(keccak256(abi.encodePacked(key)));
        _addKey(keyHash, key);
        _set(keyHash, key, value, tokenId);
    }

    function setMany(
        string[] calldata keys,
        string[] calldata values,
        uint256 tokenId
    ) external override authorised(tokenId) {
        for (uint256 i = 0; i < keys.length; i++) {
            _set(keys[i], values[i], tokenId);
        }
    }

    function setByHash(
        uint256 keyHash,
        string calldata value,
        uint256 tokenId
    ) external override authorised(tokenId) {
        require(_existsKey(keyHash), 'Resolver: KEY_NOT_FOUND');
        _set(keyHash, getKey(keyHash), value, tokenId);
    }

    function setManyByHash(
        uint256[] calldata keyHashes,
        string[] calldata values,
        uint256 tokenId
    ) external override authorised(tokenId) {
        for (uint256 i = 0; i < keyHashes.length; i++) {
            require(_existsKey(keyHashes[i]), 'Resolver: KEY_NOT_FOUND');
            _set(keyHashes[i], getKey(keyHashes[i]), values[i], tokenId);
        }
    }

}
