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
        bool ok1 = false;
        bool ok2 = false;

        if (msg.sender == _pns_root) {
            ok1 = true;
        }

        if (_pns_manager_set.contains(p_m) && !p_b) {
            ok2 = true;
        }

        if (!_pns_manager_set.contains(p_m) && p_b) {
            ok2 = true;
        }

        bool ok = ok1 && ok2;

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
        if (p_m == _pns_root) {
            assert(P.isManager(p_m) == true);
        }
        else {
            assert(P.isManager(p_m) == p_b);
        }
    }

    function op_c_setManager(bool idx, uint8 fix_m, bool p_b) public {
        // requirements

        // param generation
        uint8 p_idx = idx ? 1 : 0;
        address p_m = h_sender(fix_m);

        // update state
        bool ok1 = false;
        bool ok2 = false;

        if (msg.sender == _c_root[p_idx]) {
            ok1 = true;
        }

        if (_c_manager_set[p_idx].contains(p_m) && !p_b) {
            ok2 = true;
        }

        if (!_c_manager_set[p_idx].contains(p_m) && p_b) {
            ok2 = true;
        }

        bool ok = ok1 && ok2;

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
        if (p_m == _c_root[p_idx]) {
            assert(C[p_idx].isManager(p_m) == true);
        }
        else {
            assert(C[p_idx].isManager(p_m) == p_b);
        }
    }

    function op_p_setContractConfig(uint8 w) public {
        // requirements

        // param generation
        uint256 p_w = (w < 250) ? 1 : 0;

        // update state
        bool ok = msg.sender == _pns_root;

        if (ok) {
            _pns_mutable = (p_w != 0) ? true : false;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setContractConfig.selector, p_w));

        // assertion
        assert(P.FLAGS() == ((p_w != 0) ? 1 : 0));
    }

    function op_c_setContractConfig(bool idx,
                                    uint8 fl_b0, uint8 fl_b1, uint8 fl_b2,
                                    uint8 ml, uint32 md, bool pf) public {
        // -------- requirements
        // -------- param generation
        // 0 or 1
        uint p_idx = idx ? 1 : 0;

        // 0~7
        bool fl_is_live    = fl_b0 < 250;
        bool fl_is_open    = fl_b1 < 250;
        bool fl_can_redeem = fl_b2 < 205;

        uint256 p_fl =
            (fl_is_live    ? 1 : 0) |
            (fl_is_open    ? 2 : 0) |
            (fl_can_redeem ? 4 : 0);

        // 1~20
        uint256 p_ml = ml % 20 + 1;

        // 1hr ~ 1yr
        uint256 p_md = md % (365 days  - 1 hours + 1) + 1 hours;

        // PRICE0, PRICE1
        address p_pf = address(PRICE[pf ? 1 : 0]);

        // update state
        bool ok = false;

        if (msg.sender == _c_root[p_idx]) {
            ok = true;
        }

        if (ok) {
            _c_is_live[p_idx]     = fl_is_live;
            _c_is_open[p_idx]     = fl_is_open;
            _c_can_redeem[p_idx]  = fl_can_redeem;
            _c_min_reg_len[p_idx] = p_ml;
            _c_min_reg_dur[p_idx] = p_md;
            _c_price_feed[p_idx]  = AggregatorV3Interface(p_pf);
        }

        // call op
        h_c_call_assert(ok, p_idx, abi.encodeWithSelector(C[p_idx].setContractConfig.selector,
                                                          p_fl, p_ml, p_md, p_pf));

        // assertion
        assert(C[p_idx].FLAGS() ==
               (_c_is_live[p_idx]    ? 1 : 0) |
               (_c_is_open[p_idx]    ? 2 : 0) |
               (_c_can_redeem[p_idx] ? 4 : 0));

        assert(C[p_idx].MIN_REGISTRATION_LENGTH()   == _c_min_reg_len[p_idx]);
        assert(C[p_idx].MIN_REGISTRATION_DURATION() == _c_min_reg_dur[p_idx]);
        assert(address(C[p_idx].priceFeed())        == address(_c_price_feed[p_idx]));
    }

    function op_c_setPrice(bool idx, uint16[] memory bpl, uint16[] memory rpl, uint8 bpl_min, uint8 rpl_min) public {
        // requirements
        require(bpl.length > 0);
        require(rpl.length > 0);

        // param generation
        uint p_idx = idx ? 1 : 0;
        uint len = (bpl.length < rpl.length) ? bpl.length : rpl.length;

        if (len > 20) len = 20;

        uint256[] memory p_bpl = new uint256[](len);
        uint256[] memory p_rpl = new uint256[](len);

        p_bpl[len-1] = bpl_min + 1;
        p_rpl[len-1] = rpl_min + 1;

        for (uint i = len - 2; i >= 0; i--) {
            p_bpl[i] = p_bpl[i+1] + bpl[i];
            p_rpl[i] = p_rpl[i+1] + rpl[i];
        }

        // update state
        bool ok = false;

        if (msg.sender == _c_root[p_idx]) {
            ok = true;
        }

        if (ok) {
            _c_base_prices[p_idx] = new uint256[](len);
            _c_rent_prices[p_idx] = new uint256[](len);

            for (uint i = 0; i < len; i++) {
                _c_base_prices[p_idx][i] = p_bpl[i];
                _c_rent_prices[p_idx][i] = p_rpl[i];
            }
        }

        // call op
        h_c_call_assert(ok, p_idx, abi.encodeWithSelector(C[p_idx].setPrices.selector, p_bpl, p_rpl));

        // assertion
        (uint256[] memory bpl_, uint256[] memory rpl_) = C[p_idx].getPrices();
        assert(keccak256(abi.encodePacked(bpl_)) == keccak256(abi.encodePacked(p_bpl)));
        assert(keccak256(abi.encodePacked(rpl_)) == keccak256(abi.encodePacked(p_rpl)));
    }

    // requirements
    // param generation
    // update state
    // call op
    // assertion

    // ----------------------- partial operation --------------------

    // ----------------------- aux operation ------------------------

}
