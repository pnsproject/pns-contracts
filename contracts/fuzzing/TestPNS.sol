// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../pns/PNS.sol";
import "../pns/PNSController.sol";

import "./EchidnaInit.sol";
import "./IHEVM.sol";

contract TestPNS is EchidnaInit {
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

    // ------------------------- helper function -------------------
    function h_sender(uint8 idx) internal view returns(address) {
        return SENDER_POOL.at(idx % SENDER_POOL.length());
    }

    function h_sender_with_c(uint8 idx) internal view returns(address) {
        uint len = SENDER_POOL.length();
        idx = uint8(idx % (2 + len));

        if (idx >= len) {
            return address(C[idx - len]);
        }
        else {
            return SENDER_POOL.at(idx);
        }
    }

    function h_call(address c, bytes memory d) internal returns(bool, bytes memory) {
        (bool success, bytes memory returndata) = c.call(abi.encodePacked(d, msg.sender));
        return (success, returndata);
    }

    function h_call_assert(bool ok, address c, bytes memory d) internal returns(bytes memory) {
        (bool ok_, bytes memory r) = h_call(c, d);
        assert(ok_ == ok);
        return r;
    }

    function h_p_call(bytes memory d) internal returns(bool, bytes memory) {
        return h_call(address(P), d);
    }

    function h_p_call_assert(bool ok, bytes memory d) internal returns(bytes memory) {
        return h_call_assert(ok, address(P), d);
    }

    function h_c_call(uint idx, bytes memory d) internal returns(bool, bytes memory) {
        return h_call(address(C[idx]), d);
    }

    function h_c_call_assert(bool ok, uint idx, bytes memory d) internal returns(bytes memory) {
        return h_call_assert(ok, address(C[idx]), d);
    }

    // ---------------------- operation ---------------------------
    function op_p_transferRootOwnership(uint8 fix_r, address p_r) public {
        // requirements

        // param generation
        if (fix_r < 250) {
            p_r = h_sender(fix_r);
        }
        else {
            fix_r = 0; // dummy
        }

        // update state
        bool ok = false;

        if (msg.sender == _pns_root) {
            ok = true;
        }

        if (ok) {
            _pns_root = p_r;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.transferRootOwnership.selector, p_r));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.root() == p_r);
    }

    function op_c_transferRootOwnership(bool idx, uint8 fix_r, address p_r) public {
        // requirements

        // param generation
        if (fix_r < 250) {
            p_r = h_sender(fix_r);
        }
        else {
            fix_r = 0;
        }

        uint8 p_idx = idx ? 1 : 0;

        // update state
        bool ok = false;

        if (msg.sender == _c_root[p_idx]) {
            ok = true;
        }

        if (ok) {
            _c_root[p_idx] = p_r;
        }

        // call op
        h_c_call_assert(ok, p_idx, abi.encodeWithSelector(C[p_idx].transferRootOwnership.selector, p_r));

        if (!ok) {
            return;
        }

        // assertion
        assert(C[p_idx].root() == p_r);
    }

    function op_p_setManager(uint8 fix_m, bool p_b) public {
        // requirements

        // param generation
        address p_m = h_sender_with_c(fix_m);

        // update state
        bool ok = false;

        if (msg.sender == _pns_root) {
            ok = true;
        }

        if (ok) {
            if (p_b) {
                _pns_manager_set.add(p_m);
            }
            else {
                _pns_manager_set.remove(p_m);
            }
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setManager.selector, p_m, p_b));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.isManager(p_m) == p_b);
    }

    function op_c_setManager(bool idx, uint8 fix_m, bool p_b) public {
        // requirements

        // param generation
        uint8 p_idx = idx ? 1 : 0;
        address p_m = h_sender(fix_m);

        // update state
        bool ok = false;

        if (msg.sender == _c_root[p_idx]) {
            ok = true;
        }

        if (ok) {
            if (p_b) {
                _c_manager_set[p_idx].add(p_m);
            }
            else {
                _c_manager_set[p_idx].remove(p_m);
            }
        }

        // call op
        h_c_call_assert(ok, p_idx, abi.encodeWithSelector(C[p_idx].setManager.selector, p_m, p_b));

        if (!ok) {
            return;
        }

        // assertion
        assert(C[p_idx].isManager(p_m) == p_b);
    }

    // requirements
    // param generation
    // update state
    // call op
    // assertion

    // ----------------------- partial operation --------------------

    // ----------------------- aux operation ------------------------

}
