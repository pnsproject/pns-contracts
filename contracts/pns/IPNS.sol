// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

pragma solidity ^0.8.0;

interface IPNS is IERC721MetadataUpgradeable {

    event NewResolver(uint256 tokenId, address resolver);

    event NewSubdomain(address to, uint256 tokenId, uint256 subtokenId, string name);

    function GRACE_PERIOD() external returns(uint256);

    function mintSubdomain(address to, uint256 tokenId, string calldata name) external returns (uint256);

    function burn(uint256 tokenId) external;

    function isApprovedOrOwner(address addr, uint256 tokenId) external view returns(bool);

    function exists(uint256 tokenId) external view returns(bool);

    function mint(address to, uint256 newTokenId) external;

    function bounded(uint256 tokenId) external view returns (bool);

    function bound(uint256 tokenId) external;

    function origin(uint256 tokenId) external view returns(uint256);

    function parent(uint256 tokenId) external view returns(uint256);

    function expire(uint256 tokenId) external view returns(uint256);

    function available(uint256 tokenId) external view returns(bool);

    function register(string calldata name, address to, uint256 duration, uint256 BASE_NODE) external returns(uint256);

    function renew(uint256 id, uint256 duration) external returns(uint256);
}
