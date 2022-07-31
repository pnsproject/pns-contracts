// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

library StringUtils {
    // return true if s contain only '0-9A-Za-z' & '-', and is not empty
    function domainPrefixValid(string calldata s) internal pure returns(bool) {
        uint len = bytes(s).length;
        if (len == 0) return false;

        for (uint i = 0; i < len; i++) {
            uint8 b = uint8(bytes(s)[i]);

            // 0 ~ 9 -> 0x30 ~ 0x39
            // A ~ Z -> 0x41 ~ 0x5A
            // a ~ z -> 0x61 ~ 0x7A
            // -     -> 0x2d
            if (b == 0x2d) continue;

            if (b < 0x30) return false;
            if (b > 0x7A) return false;

            if (b <= 0x39) continue;
            if (b >= 0x61) continue;

            if ((0x41 <= b) && (b <= 0x5A)) continue;

            return false;
        }

        return true;
    }

    /**
     * @dev Returns the length of a given string
     *
     * @param s The string to measure the length of
     * @return The length of the input string
     */
    function strlen(string memory s) internal pure returns (uint) {
        uint len;
        uint i = 0;
        uint bytelength = bytes(s).length;
        for(len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if(b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }
}
