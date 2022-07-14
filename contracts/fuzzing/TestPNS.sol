// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./EchidnaInit.sol";
import "./IHEVM.sol";
import "./OpenForwarder.sol";

contract TestPNS is EchidnaInit, OpenForwarder {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    using ECDSA for bytes32;

    IHEVM HEVM = IHEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    event AssertionFailed(string message);

    // ------------------------ state ----------------------

    // -------- pns
    bool _pns_mutable = true;

    mapping(uint256 => address) _pns_approve_tbl;

    EnumerableSet.UintSet       _pns_sld_set;
    mapping(uint256 => uint256) _pns_sld_expire_tbl;

    EnumerableSet.UintSet       _pns_sd_set;
    mapping(uint256 => uint256) _pns_sd_origin_tbl;
    mapping(uint256 => uint256) _pns_sd_parent_tbl;

    EnumerableSet.UintSet _pns_bound_set;

    mapping(uint256 => mapping(uint256 => uint256)) _pns_info_link_tbl;
    mapping(uint256 => mapping(uint256 => string))  _pns_info_record_tbl;
    mapping(address => uint256)                     _pns_info_name_tbl;
    mapping(address => mapping(uint256 => uint256)) _pns_info_nft_name_tbl;

    mapping(uint256 => address) _pns_key_tbl;


    // --------- controller
    uint256[2] _c_min_reg_dur = [28 days , 28 days];
    uint256[2] _c_min_reg_len = [10      , 10];

    bool[2] _c_is_live    = [true, true];
    bool[2] _c_is_open    = [true, true];
    bool[2] _c_can_redeem = [true, true];

    // ----------------------
}
