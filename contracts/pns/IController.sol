// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/RootOwnable.sol";

interface IMulticallable {
    function multicall(bytes[] calldata data) external returns(bytes[] memory results);
}

interface IController {

    event PriceChanged(uint256[] basePrices, uint256[] rentPrices);
    event ConfigUpdated(uint256 flags);
    event CapacityUpdated(uint256 tokenId, uint256 capacity);
    event NameRenewed(uint256 node, uint256 cost, uint256 expires, string name);
    event NameRegistered(address to, uint256 node, uint256 cost, uint256 expires, string name);

    function nameRegisterByManager(string calldata name, address owner, uint64 duration, uint256 data, uint256[] calldata keyHashes, string[] calldata values) external returns(uint256);

    function nameRegister(string calldata name, address owner, uint64 duration) external payable returns(uint256);

    function nameRegisterWithConfig(string calldata name, address owner, uint64 duration, uint256 data, uint256[] calldata keyHashes, string[] calldata values) external payable returns(uint256);

    function renew(string calldata name, uint64 duration) external payable;

    function renewByManager(string calldata name, uint64 duration) external;

    function nameRedeem(string calldata name, address owner, uint64 duration, uint256 deadline, bytes memory code) external returns(uint256);

    function getTokenPrice() external view returns (int);

    function setPrices(uint256[] memory basePrices, uint256[] memory rentPrices) external;

    function getPrices() view external returns(uint256[] memory, uint256[] memory);

    function totalRegisterPrice(string memory name, uint64 duration) view external returns(uint256);

    function renewPrice(string memory name, uint64 duration) view external returns(uint256);

    function basePrice(string memory name) view external returns(uint256);

    function rentPrice(string memory name, uint64 duration) view external returns(uint256);
}
