// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IResolver {

    event NewKey(string indexed keyIndex, string key);
    event Set(uint256 indexed tokenId, uint256 indexed keyHash, string value);
    event ResetRecords(uint256 indexed tokenId);

    event SetName(address indexed addr, uint256 indexed tokenId);
    event SetNftName(address indexed nftAddr, uint256 indexed nftTokenId, uint256 indexed tokenId);

    function getName(address addr) external view returns (uint256);
    function setName(uint256 tokenId ) external;

    function getNftName(address nftAddr, uint256 nftTokenId) external view returns (uint256);
    function setNftName(address nft, uint256 nftTokenId, uint256 nameTokenId ) external;

    function getKey(uint256 keyHash) external view returns (string memory);
    function addKeys(string[] memory keys) external;

    function get(string calldata key, uint256 tokenId) external view returns (string memory);
    function getMany(string[] calldata keys, uint256 tokenId) external view returns (string[] memory);
    function getByHash(uint256 keyHash, uint256 tokenId) external view returns (string memory value);
    function getManyByHash(uint256[] calldata keyHashes, uint256 tokenId) external view returns (string[] memory values);
    function setByHash(uint256 keyHash, string calldata value, uint256 tokenId ) external;
    function setManyByHash(uint256[] calldata keyHashes, string[] calldata values, uint256 tokenId ) external;
}
