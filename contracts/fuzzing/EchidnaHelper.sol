// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./IHEVM.sol";

contract EchidnaHelper {
    IHEVM HEVM = IHEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    event AssertionFailed(string message);

    event Debug(string m);


    function debug(bytes memory str) internal {
        emit Debug(string(str));
    }

    function assert_eq(string memory desc, bool eq1, bool eq2) internal {
        if (eq1 != eq2) {
            debug(abi.encodePacked("assert fail, ", desc, ", get: ", eq1 ? "true" : "false",
                                   ", exp: ", eq2 ? "true" : "false"));
        }

        assert(eq1 == eq2);
    }

    function assert_eq(string memory desc, uint eq1, uint eq2) internal {
        if (eq1 != eq2) {
            debug(abi.encodePacked("assert fail, ", desc, ", get: ", Strings.toHexString(eq1),
                                   ", exp: ", Strings.toHexString(eq2)));
        }

        assert(eq1 == eq2);
    }

    function assert_eq(string memory desc, address eq1, address eq2) internal {
        if (eq1 != eq2) {
            debug(abi.encodePacked("assert fail, ", desc, ", get: ", Strings.toHexString(uint160(eq1)),
                                   ", exp: ", Strings.toHexString(uint160(eq2))));
        }

        assert(eq1 == eq2);
    }

    function assert_eq(string memory desc, string memory eq1, string memory eq2) internal {
        if (keccak256(bytes(eq1)) != keccak256(bytes(eq2))) {
            debug(abi.encodePacked("assert fail, ", desc, ", get: ", eq1,
                                   ", exp: ", eq2));
        }

        assert(keccak256(bytes(eq1)) == keccak256(bytes(eq2)));
    }
}
