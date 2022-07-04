// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/metatx/MinimalForwarderUpgradeable.sol";

contract PNSForwarder is MinimalForwarderUpgradeable {
    function initialize() initializer public {
        __EIP712_init("PNSForwarder", "0.1.0");
    }
}
