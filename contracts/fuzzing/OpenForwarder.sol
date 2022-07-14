// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// see MinimalForwarderUpgradeable, @openzepplin

// open forward not check anything
contract OpenForwarder {
    function execute(address from, address to, bytes memory data)
        public
        returns (bool, bytes memory)
    {
        (bool success, bytes memory returndata) = to.call(abi.encodePacked(data, from));
        return (success, returndata);
    }
}
