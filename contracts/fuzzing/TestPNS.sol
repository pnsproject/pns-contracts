// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../pns/PNS.sol";
import "../pns/PNSController.sol";
import "../test/PriceOracle.sol";

import "./EchidnaInit.sol";
import "./IHEVM.sol";
import "./Math512.sol";

contract TestPNS is EchidnaInit {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Math512 for Math512.uint512;

    using ECDSA for bytes32;

    IHEVM HEVM = IHEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    event AssertionFailed(string message);

    // ------------------------ state ----------------------
    // -------- const
    string[] WORD_SET = ["dot", "org", "com", "net", "www", "hello", "pns"];
    uint constant SECONDS_PER_YEAR = 365 * 86400;

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

    mapping(uint256 => string) _pns_key_tbl;


    // --------- controller
    uint256[2] _c_min_reg_dur = [28 days , 28 days];
    uint256[2] _c_min_reg_len = [10      , 10];

    bool[2] _c_is_live    = [true, true];
    bool[2] _c_is_open    = [true, true];
    bool[2] _c_can_redeem = [true, true];

    // ------------------------- init ------------------------------

    // ------------------------- helper function -------------------
    function h_sel_sender(uint8 idx) internal view returns(address) {
        return SENDER_POOL.at(idx % SENDER_POOL.length());
    }

    function h_sel_sender_alt(uint8 idx, uint8 thres, address alt) internal view returns(address) {
        if (idx < thres) return h_sel_sender(idx);
        return alt;
    }

    function h_sel_sender_with_c(uint8 idx) internal view returns(address) {
        uint len = SENDER_POOL.length();
        idx = uint8(idx % (2 + len));

        if (idx >= len) {
            return address(C[idx - len]);
        }
        else {
            return SENDER_POOL.at(idx);
        }
    }

    function h_sel_sender_with_nft(uint8 idx) internal view returns(address) {
        uint len = SENDER_POOL.length();
        idx = uint8(idx % (2 + len));

        if (idx >= len) {
            return address(NFT[idx - len]);
        }
        else {
            return SENDER_POOL.at(idx);
        }
    }

    function h_sel_word(uint8 idx) internal view returns(string memory) {
        return WORD_SET[idx % WORD_SET.length];
    }

    function h_sel_word_alt(uint8 idx, uint8 thres, string memory alt) internal view returns(string memory) {
        if (idx < thres) return h_sel_word(idx);
        return alt;
    }

    function h_sel_token(uint8 idx) internal view returns(uint256) {
        return _pns_token_set.at(idx % _pns_token_set.length());
    }

    function h_sel_token_alt(uint8 idx, uint8 thres, uint256 alt) internal view returns(uint256) {
        if (idx < thres) return h_sel_token(idx);
        return alt;
    }

    function h_sel_owned_token(uint8 idx) internal view returns(uint256 tok) {
        (tok, ) = _pns_owner_tbl.at(idx % _pns_owner_tbl.length());
    }

    function h_namehash(string memory prefix, uint256 base) internal pure returns(uint256) {
        return uint256(keccak256(abi.encodePacked(base, keccak256(bytes(prefix)))));
    }

    function h_pns_owner_is(uint256 tok, address owner) internal view returns(bool) {
        if (!_pns_owner_tbl.contains(tok)) return false;
        return _pns_owner_tbl.get(tok) == owner;
    }

    function h_call(address c, uint256 v, bytes memory d) internal returns(bool, bytes memory) {
        (bool success, bytes memory returndata) = c.call{value: v}(abi.encodePacked(d, msg.sender));
        return (success, returndata);
    }

    function h_call_assert(bool ok, address c, uint256 v, bytes memory d) internal returns(bytes memory) {
        (bool ok_, bytes memory r) = h_call(c, v, d);
        assert(ok_ == ok);
        return r;
    }

    function h_p_call(bytes memory d) internal returns(bool, bytes memory) {
        return h_call(address(P), 0, d);
    }

    function h_p_call_assert(bool ok, bytes memory d) internal returns(bytes memory) {
        return h_call_assert(ok, address(P), 0, d);
    }

    function h_c_call(uint idx, bytes memory d) internal returns(bool, bytes memory) {
        return h_call(address(C[idx]), 0, d);
    }

    function h_c_call_assert(bool ok, uint idx, bytes memory d) internal returns(bytes memory) {
        return h_call_assert(ok, address(C[idx]), 0, d);
    }

    function h_c_call_with_value_assert(bool ok, uint idx, uint256 v, bytes memory d)
        internal
        returns(bytes memory)
    {
        return h_call_assert(ok, address(C[idx]), v, d);
    }

    function h_get_price(uint idx) internal view returns(uint256) {
        (,int x,,,) = _c_price_feed[idx].latestRoundData();

        return uint256(x);
    }

    function h_sign_hash(uint256 sk, bytes32 hash) internal returns(bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = HEVM.sign(sk, hash);

        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            s = bytes32(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - uint256(s));
            v = (v == 28) ? 27 : 28;
        }

        return abi.encodePacked(r, s, v);
    }

    function h_str_eq(string memory a, string memory b) internal pure returns(bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function h_str_ary_eq(string[] memory a, string[] memory b) internal pure returns(bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }

    // ---------------------- operation ---------------------------
    function op_p_transferRootOwnership(uint8 fix_r, address p_r) public {
        // requirements

        // param generation
        if (fix_r < 200) {
            p_r = h_sel_sender(fix_r);
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
        if (fix_r < 200) {
            p_r = h_sel_sender(fix_r);
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
        address p_m = h_sel_sender_with_c(fix_m);

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
        address p_m = h_sel_sender(fix_m);

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
        uint256 p_w = (w < 200) ? 1 : 0;

        // update state
        bool ok = msg.sender == _pns_root;

        if (ok) {
            _pns_mutable = (p_w != 0) ? true : false;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setContractConfig.selector, p_w));

        if (!ok) {
            return;
        }

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
        bool fl_is_live    = fl_b0 < 200;
        bool fl_is_open    = fl_b1 < 200;
        bool fl_can_redeem = fl_b2 < 200;

        uint256 p_fl =
            (fl_is_live    ? 1 : 0) |
            (fl_is_open    ? 2 : 0) |
            (fl_can_redeem ? 4 : 0);

        // 1~20
        uint256 p_ml = ml % 20 + 1;

        // 1hr ~ 1yr
        uint256 p_md = md % (365 days  - 1 hours + 1) + 1 hours;

        // PRICE0, PRICE1
        uint pf_idx = pf ? 1 : 0;
        address p_pf = address(PRICE[pf_idx]);

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

        if (!ok) {
            return;
        }

        // assertion
        assert(C[p_idx].FLAGS() ==
               (_c_is_live[p_idx]    ? 1 : 0) |
               (_c_is_open[p_idx]    ? 2 : 0) |
               (_c_can_redeem[p_idx] ? 4 : 0));

        assert(C[p_idx].MIN_REGISTRATION_LENGTH()   == _c_min_reg_len[p_idx]);
        assert(C[p_idx].MIN_REGISTRATION_DURATION() == _c_min_reg_dur[p_idx]);
        assert(address(C[p_idx].priceFeed())        == address(_c_price_feed[p_idx]));
    }

    function op_c_setPrice(bool idx, uint24[] memory bpl, uint24[] memory rpl, uint8 bpl_min, uint8 rpl_min) public {
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

        if (!ok) {
            return;
        }

        // assertion
        (uint256[] memory bpl_, uint256[] memory rpl_) = C[p_idx].getPrices();
        assert(keccak256(abi.encodePacked(bpl_)) == keccak256(abi.encodePacked(p_bpl)));
        assert(keccak256(abi.encodePacked(rpl_)) == keccak256(abi.encodePacked(p_rpl)));
    }

    function op_p_mint(uint8 to, uint8 tok) public {
        // requirements
        // param generation
        address p_to = h_sel_sender(to);
        uint256 p_tok = h_namehash(h_sel_word(tok), 0);

        // update state
        bool ok = false;

        bool ok1 = false;
        if (msg.sender == _pns_root) {
            ok1 = true;
        }

        bool ok2 = false;
        if (p_to != address(0)) {
            ok2 = true;
        }

        bool ok3 = false;
        if (!_pns_owner_tbl.contains(p_tok)) {
            ok3 = true;
        }

        ok = ok1 && ok2 && ok3;

        if (ok) {
            _pns_owner_tbl.set(p_tok, p_to);
            _pns_token_set.add(p_tok);
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.mint.selector, p_to, p_tok));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.exists(p_tok));
        assert(P.ownerOf(p_tok) == p_to);
    }

    // NOTE: variable naming style change:
    // for above ops, p_* is actual parameter, and * is index
    // for below ops, *_idx is index, and * is parameter

    function op_p_mintSubdomain
        (uint8 to_idx, address to1,
         uint8 ptok_idx, uint256 ptok1,
         uint8 name_idx, string memory name1)
        public
    {
        // requirements
        uint len_sld = _pns_sld_set.length();
        uint len_sd  = _pns_sd_set.length();

        if ((msg.sender == _pns_root) || (_pns_manager_set.contains(msg.sender))) {
            require(len_sld + len_sd > 0, "2nd level domain or more level domain should not empty");
        }

        // param generation
        address to = h_sel_sender_alt(to_idx, 200, to1);
        string memory name = h_sel_word_alt(name_idx, 200, name1);

        uint256 ptok;

        if ((msg.sender == _pns_root) || (_pns_manager_set.contains(msg.sender))) {
            ptok_idx = uint8(ptok_idx % (len_sld + len_sd));
            if (ptok_idx >= len_sld) {
                ptok = _pns_sd_set.at(ptok_idx - len_sld);
            }
            else {
                ptok = _pns_sld_set.at(ptok_idx);
            }
        }
        else {
            ptok = h_sel_token_alt(ptok_idx, 200, ptok1);
        }

        uint256 stok = h_namehash(name, ptok);

        // update state
        bool ok = false;

        bool ok1 = false;
        if (msg.sender == _pns_root) {
            ok1 = true;
        }
        if (_pns_manager_set.contains(msg.sender)) {
            ok1 = true;
        }
        if (_pns_approve_tbl[ptok] == msg.sender) {
            ok1 = true;
        }
        if (h_pns_owner_is(ptok, msg.sender)) {
            ok1 = true;
        }

        bool ok2 = false;
        if (to != address(0)) {
            ok2 = true;
        }

        bool ok3 = false;
        if (!_pns_owner_tbl.contains(stok)) {
            ok3 = true;
        }

        ok = ok1 && ok2 && ok3;

        if (ok) {
            _pns_owner_tbl.set(stok, to);

            _pns_sd_set.add(stok);
            _pns_sd_parent_tbl[stok] = ptok;

            if (_pns_sld_set.contains(ptok)) {
                _pns_sd_origin_tbl[stok] = ptok;
            }
            else {
                _pns_sd_origin_tbl[stok] = _pns_sd_origin_tbl[ptok];
            }

            _pns_token_set.add(stok);
        }

        // call op
        uint256 ret = abi.decode(h_p_call_assert(ok, abi.encodeWithSelector(P.mintSubdomain.selector,
                                                                            to, ptok, name)),
                                 (uint256));

        if (!ok) {
            return;
        }

        // assertion
        assert(ret == stok);
        assert(P.exists(stok));
        assert(P.ownerOf(stok) == to);
        assert(P.nameExpired(stok) == (_pns_sld_expire_tbl[_pns_sd_origin_tbl[stok]] + GRACE_PERIOD < block.timestamp));
        assert(!P.available(stok));
        assert(P.origin(stok) == _pns_sd_origin_tbl[stok]);
        assert(P.parent(stok) == ptok);
    }

    function op_p_burn(uint8 tok_idx, uint256 tok1) public {
        // requirements
        // param generation
        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // update state
        bool ok;

        bool ok1 = false;
        if (_pns_owner_tbl.contains(tok)) {
            ok1 = true;
        }

        bool ok2 = false;
        if (P.nameExpired(tok) && !_pns_bound_set.contains(tok)) {
            ok2 = true;
        }
        if (msg.sender == _pns_root) {
            ok2 = true;
        }
        if (h_pns_owner_is(tok, msg.sender)) {
            ok2 = true;
        }
        if (msg.sender == _pns_approve_tbl[tok]) {
            ok2 = true;
        }
        if (h_pns_owner_is(_pns_sd_origin_tbl[tok], msg.sender)) {
            ok2 = true;
        }
        if (_pns_approve_tbl[_pns_sd_origin_tbl[tok]] == msg.sender) {
            ok2 = true;
        }

        ok = ok1 && ok2;

        if (ok) {
            _pns_owner_tbl.remove(tok);
            _pns_sld_set.remove(tok);
            _pns_sd_set.remove(tok);
            _pns_sd_parent_tbl[tok] = 0;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.burn.selector, tok));

        if (!ok) {
            return;
        }

        // assertion
        assert(!P.exists(tok));
        assert(P.origin(tok) == 0);
        assert(P.expire(tok) == 0);
    }

    function op_p_bound(uint8 tok_idx, uint256 tok1) public {
        // requirements
        // param generation
        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // update state
        bool ok = false;

        bool ok1 = false;
        if (msg.sender == _pns_root) {
            ok1 = true;
        }
        if (_pns_manager_set.contains(msg.sender)) {
            ok1 = true;
        }
        if (h_pns_owner_is(tok, msg.sender)) {
            ok1 = true;
        }
        if (_pns_approve_tbl[tok] == msg.sender) {
            ok1 = true;
        }

        bool ok2 = false;
        if (_pns_sld_set.contains(tok)) {
            ok2 = true;
        }
        if (_pns_bound_set.contains(_pns_sd_origin_tbl[tok])) {
            ok2 = true;
        }

        ok = ok1 && ok2;

        if (ok) {
            _pns_bound_set.add(tok);
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.bound.selector, tok));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.bounded(tok));
    }

    struct SetMetadataBatchArg {
        uint8 tok_idx;
        uint8 origin_idx;
        uint32 expire1;
        uint8 parent_idx;
    }

    function op_p_setMetadataBatch(SetMetadataBatchArg[] memory args) public {
        // requirements
        // param generation
        uint len = args.length;

        uint256[] memory toks = new uint256[](len);
        PNS.Record[] memory recs = new PNS.Record[](len);

        for (uint i = 0; i < len; i++) {
            bool is_sld = args[i].origin_idx > 128;

            toks[i] = h_sel_owned_token(args[i].tok_idx);
            recs[i].origin = is_sld ? toks[i] : h_sel_owned_token(args[i].origin_idx);
            recs[i].expire = is_sld ? (args[i].expire1 % (5 * 365 days - 1 days + 1) + 1 days) : 0;
            recs[i].parent = is_sld ? toks[i] : h_sel_owned_token(args[i].parent_idx);
        }

        // update state
        bool ok = false;

        if (msg.sender == _pns_root) {
            ok = true;
        }

        if (_pns_manager_set.contains(msg.sender)) {
            ok = true;
        }

        if (ok) {
            for (uint i = 0; i < len; i++) {
                uint256 tok = toks[i];
                PNS.Record memory rec = recs[i];

                if (rec.origin == tok) {
                    _pns_sld_expire_tbl[tok] = rec.expire;
                }
                else {
                    _pns_sd_origin_tbl[tok] = rec.origin;
                    _pns_sd_parent_tbl[tok] = rec.parent;
                }
            }
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setMetadataBatch.selector, toks, recs));

        if (!ok) {
            return;
        }

        // assertion
        for (uint i = 0; i < len; i++) {
            uint256 tok = toks[i];
            PNS.Record memory rec = recs[i];

            assert(!P.available(tok));
            assert(P.expire(tok) == rec.expire);
            assert(P.origin(tok) == rec.origin);
            assert(P.parent(tok) == rec.parent);
        }
    }

    struct CNameRegisterByManagerArgs {
        uint idx;
        string name;
        address to;
        uint256 dur;
        uint data;
        uint256[] khs;
        string[] vls;
        uint256 stok;
    }

    function gen_c_nameRegisterByManager(bool idx_idx,
                                        uint8 name_idx, string memory name1,
                                        uint8 to_idx, address to1,
                                        uint32 dur1,
                                        bool set_name,
                                        uint256[] memory khs1, uint8[] memory khs_idx,
                                        string[] memory vls1)
        internal
        view
        returns(CNameRegisterByManagerArgs memory a)
    {
        a.idx = idx_idx ? 1 : 0;
        a.name = h_sel_word_alt(name_idx, 125, name1);
        a.to = h_sel_sender_alt(to_idx, 200, to1);
        a.dur = uint256(dur1) % (5 * 365 days - 1 days + 1) + 1 days;

        a.data = set_name ? 1 : 0;

        uint len = (khs1.length < vls1.length) ? khs1.length : vls1.length;
        if (khs_idx.length < len) { len = khs_idx.length; }

        a.khs = new uint256[](len);
        a.vls = new string[](len);

        for (uint i = 0; i < len; i++) {
            if (khs_idx[i] < 240) {
                a.khs[i] = uint256(keccak256(abi.encodePacked(h_sel_word(khs_idx[i]))));
            }
            else {
                a.khs[i] = khs1[i];
            }

            a.vls[i] = vls1[i];
        }

        a.stok = h_namehash(a.name, C_BASE_NODE[a.idx]);
    }

    function cons_c_nameRegisterByManager(CNameRegisterByManagerArgs memory a)
        internal
        view
        returns(bool ok)
    {
        uint idx = a.idx;

        bool ok1 = false;
        if (_c_is_live[idx]) {
            ok1 = true;
        }

        bool ok2 = false;
        if (msg.sender == _c_root[idx]) {
            ok2 = true;
        }
        if (_c_manager_set[idx].contains(msg.sender)) {
            ok2 = true;
        }

        bool ok3 = false;
        if (!_pns_owner_tbl.contains(a.stok) && (a.to != address(0))) {
            ok3 = true;
        }

        bool ok4 = false;
        if (_pns_mutable) {
            ok4 = true;
        }

        bool ok5 = false;
        if (address(C[idx]) == _pns_root) {
            ok5 = true;
        }
        if (_pns_manager_set.contains(address(C[idx]))) {
            ok5 = true;
        }

        bool ok6 = true;
        for (uint i = 0; i < a.khs.length; i++) {
            if (bytes(_pns_key_tbl[a.khs[i]]).length == 0) {
                ok6 = false;
            }
        }

        ok = ok1 && ok2 && ok3 && ok4 && ok5 && ok6;
    }

    function op_c_nameRegisterByManager(bool idx_idx,
                                        uint8 name_idx, string memory name1,
                                        uint8 to_idx, address to1,
                                        uint32 dur1,
                                        bool set_name,
                                        uint256[] memory khs1, uint8[] memory khs_idx,
                                        string[] memory vls1)
        public
    {
        // requirements
        require((1 <= bytes(name1).length) && (bytes(name1).length <= 20));

        // param generation
        CNameRegisterByManagerArgs memory a =
            gen_c_nameRegisterByManager(idx_idx, name_idx, name1, to_idx, to1,
                                        dur1, set_name, khs1, khs_idx, vls1);

        // update state
        bool ok = cons_c_nameRegisterByManager(a);

        if (ok) {
            _pns_owner_tbl.set(a.stok, a.to);
            _pns_token_set.add(a.stok);
            _pns_sld_set.add(a.stok);
            _pns_sld_expire_tbl[a.stok] = a.dur + block.timestamp;
            if (set_name) {
                _pns_info_name_tbl[a.to] = a.stok;
            }

            for (uint i = 0; i < a.khs.length; i++) {
                _pns_info_record_tbl[a.stok][a.khs[i]] = a.vls[i];
            }
        }

        // call op
        uint256 ret =
            abi.decode(h_c_call_assert(ok, a.idx,
                                       abi.encodeWithSelector(C[a.idx].nameRegisterByManager.selector,
                                                              a.name, a.to, a.dur, a.data, a.khs, a.vls)),
                       (uint256));

        if (!ok) {
            return;
        }

        // assertion
        assert(ret == a.stok);
        assert(P.ownerOf(a.stok) == a.to);
        if (set_name) {
            assert(P.getName(a.to) == a.stok);
        }
        assert(h_str_ary_eq(P.getManyByHash(a.khs, a.stok), a.vls));
        for (uint i = 0; i < a.khs.length; i++) {
            assert(h_str_eq(P.getByHash(a.khs[i], a.stok), a.vls[i]));
        }

        assert(P.expire(a.stok) == a.dur + block.timestamp);
        assert(P.origin(a.stok) == a.stok);
        assert(P.parent(a.stok) == a.stok);
        assert(!P.available(a.stok));
    }

    struct CNameRegisterArgs {
        uint idx;
        string name;
        address to;
        uint256 dur;
        uint256 value;
        uint256 stok;
        uint256 price;
    }

    function gen_c_nameRegister(bool idx_idx,
                                uint8 name_idx, string memory name1,
                                uint8 to_idx, address to1,
                                uint8 dur_idx, uint256 dur1,
                                uint8 value_idx, uint256 value1)
        internal
        view
        returns(CNameRegisterArgs memory a)
    {
        a.idx = idx_idx ? 1 : 0;
        a.name = h_sel_word_alt(name_idx, 125, name1);
        a.to = h_sel_sender_alt(to_idx, 200, to1);

        if (dur_idx < 80) {
            // < c_min_reg_dur
            a.dur = dur1 % _c_min_reg_dur[a.idx];
        }
        else if (dur_idx < 160) {
            a.dur = _c_min_reg_dur[a.idx];
        }
        else {
            a.dur = dur1 + _c_min_reg_dur[a.idx];
        }

        string memory name_fixed = a.name;
        if (bytes(name_fixed).length == 0) { name_fixed = "1"; }

        a.price = C[a.idx].totalRegisterPrice(name_fixed, a.dur);

        if (value_idx < 80) {
            a.value = value1 % a.price;
        }
        else if (value_idx < 160) {
            a.value = a.price;
        }
        else {
            // if > balance, use remainder
            // final value may <= price
            a.value = (a.price + value1) % address(this).balance;
        }

       a.stok = h_namehash(a.name, C_BASE_NODE[a.idx]);
    }

    function cons_c_nameRegister(CNameRegisterArgs memory a)
        internal
        view
        returns(bool ok)
    {
        bool ok1 = false;
        if (_c_is_open[a.idx]) {
            ok1 = true;
        }

        bool ok2 = false;
        if (a.value >= a.price) {
            ok2 = true;
        }

        bool ok3 = false;
        if (bytes(a.name).length >= _c_min_reg_len[a.idx]) {
            ok3 = true;
        }

        bool ok4 = false;
        if (a.dur >= _c_min_reg_dur[a.idx]) {
            ok4 = true;
        }

        bool ok5 = false;
        unchecked {
            if (block.timestamp + a.dur + GRACE_PERIOD > block.timestamp + GRACE_PERIOD) {
                ok5 = true;
            }
        }

        bool ok6 = false;
        if (!_pns_owner_tbl.contains(a.stok) && (a.to != address(0))) {
            ok6 = true;
        }

        bool ok7 = false;
        if (address(C[a.idx]) == _pns_root) {
            ok7 = true;
        }
        if (_pns_manager_set.contains(address(C[a.idx]))) {
            ok7 = true;
        }

        ok = ok1 && ok2 && ok3 && ok4 && ok5 && ok6 && ok7;
    }


    function up_c_nameRegister(CNameRegisterArgs memory a) internal {
        _pns_owner_tbl.set(a.stok, a.to);
        _pns_token_set.add(a.stok);
        _pns_sld_set.add(a.stok);
        _pns_sld_expire_tbl[a.stok] = a.dur + block.timestamp;
    }

    function ast_c_nameRegister(CNameRegisterArgs memory a,
                                uint256 balance_root, uint256 balance_sender, uint256 ret)
        internal view
    {
        uint256 balance_root_new = _c_root[a.idx].balance;
        uint256 balance_sender_new = msg.sender.balance;

        assert(ret == a.stok);
        assert(P.ownerOf(a.stok) == a.to);
        assert(P.expire(a.stok) == a.dur + block.timestamp);
        assert(P.origin(a.stok) == a.stok);
        assert(P.parent(a.stok) == a.stok);
        assert(!P.available(a.stok));

        assert(balance_root_new == balance_root + a.price);
        assert(balance_sender_new == balance_sender + a.value - a.price);
    }

    function op_c_nameRegister(bool idx_idx,
                               uint8 name_idx, string memory name1,
                               uint8 to_idx, address to1,
                               uint8 dur_idx, uint256 dur1,
                               uint8 value_idx, uint256 value1)
        public
    {
        // requirements
        // param generation
        CNameRegisterArgs memory a = gen_c_nameRegister(idx_idx, name_idx, name1,
                                                        to_idx, to1,
                                                        dur_idx, dur1,
                                                        value_idx, value1);


        // update state
        bool ok = cons_c_nameRegister(a);

        if (ok) {
            up_c_nameRegister(a);
        }

        // call op
        uint256 balance_root   = _c_root[a.idx].balance;
        uint256 balance_sender = msg.sender.balance;

        uint256 ret =
            abi.decode(h_c_call_with_value_assert(ok, a.idx, a.value,
                                                  abi.encodeWithSelector(C[a.idx].nameRegister.selector,
                                                                         a.name, a.to, a.dur)),
                       (uint256));

        if (!ok) {
            return;
        }

        // assertion
        ast_c_nameRegister(a, balance_root, balance_sender, ret);
    }

    struct CNameRegisterWithConfigFuzzingArgs {
        bool idx_idx;
        uint8 name_idx; string name1;
        uint8 to_idx; address to1;
        uint8 dur_idx; uint256 dur1;
        uint8 value_idx; uint256 value1;
        bool set_name;
        uint256[] khs1; uint8[] khs_idx;
        uint8 vls_idx; string[] vls1;
    }

    struct CNameRegisterWithConfigArgs {
        uint data;
        uint256[] khs;
        string[] vls;
    }

    function gen_c_nameRegisterWithConfig(CNameRegisterWithConfigFuzzingArgs memory fa)
        internal view
        returns(CNameRegisterWithConfigArgs memory ca)
    {
        ca.data = fa.set_name ? 1 : 0;

        uint len = (fa.khs1.length < fa.vls1.length) ? fa.khs1.length : fa.vls1.length;
        if (fa.khs_idx.length < len) { len = fa.khs_idx.length; }

        ca.khs = new uint256[](len);
        string[] memory vls2 = new string[](len);

        for (uint i = 0; i < len; i++) {
            if (fa.khs_idx[i] < 240) {
                ca.khs[i] = uint256(keccak256(abi.encodePacked(h_sel_word(fa.khs_idx[i]))));
            }
            else {
                ca.khs[i] = fa.khs1[i];
            }

            vls2[i] = fa.vls1[i];
        }

        if (fa.vls_idx < 200) {
            ca.vls = vls2;
        }
        else {
            ca.vls = fa.vls1;
        }
    }

    function cons_c_nameRegisterWithConfig(CNameRegisterArgs memory a,
                                           CNameRegisterWithConfigArgs memory ca)
        internal view
        returns(bool ok)
    {
        bool ok1 = false;
        if (cons_c_nameRegister(a)) {
            ok1 = true;
        }

        bool ok2 = false;
        if (_pns_mutable) {
            ok2 = true;
        }

        bool ok3 = false;
        if (ca.vls.length == ca.khs.length) {
            ok3 = true;
        }

        bool ok4 = true;
        for (uint i = 0; i < ca.khs.length; i++) {
            if (bytes(_pns_key_tbl[ca.khs[i]]).length == 0) {
                ok4 = false;
            }
        }

        ok = ok1 && ok2 && ok3 && ok4;
    }

    function op_c_nameRegisterWithConfig(CNameRegisterWithConfigFuzzingArgs memory fa)
        public
    {
        // requirements
        // param generation
        CNameRegisterArgs memory a = gen_c_nameRegister(fa.idx_idx,
                                                        fa.name_idx, fa.name1,
                                                        fa.to_idx, fa.to1,
                                                        fa.dur_idx, fa.dur1,
                                                        fa.value_idx, fa.value1);
        CNameRegisterWithConfigArgs memory ca = gen_c_nameRegisterWithConfig(fa);

        // update state
        bool ok = cons_c_nameRegisterWithConfig(a, ca);

        if (ok) {
            up_c_nameRegister(a);

            if (fa.set_name) {
                _pns_info_name_tbl[a.to] = a.stok;
            }

            for (uint i = 0; i < ca.khs.length; i++) {
                _pns_info_record_tbl[a.stok][ca.khs[i]] = ca.vls[i];
            }
        }

        // call op
        uint256 balance_root   = _c_root[a.idx].balance;
        uint256 balance_sender = msg.sender.balance;

        uint256 ret =
            abi.decode(h_c_call_with_value_assert(ok, a.idx, a.value,
                                                  abi.encodeWithSelector(C[a.idx].nameRegisterWithConfig.selector,
                                                                         a.name, a.to, a.dur,
                                                                         ca.data, ca.khs, ca.vls)),
                       (uint256));

        if (!ok) {
            return;
        }

        // assertion
        ast_c_nameRegister(a, balance_root, balance_sender, ret);

        if (fa.set_name) {
            assert(P.getName(a.to) == a.stok);
        }

        assert(h_str_ary_eq(P.getManyByHash(ca.khs, a.stok), ca.vls));

        for (uint i = 0; i < ca.khs.length; i++) {
            assert(h_str_eq(P.getByHash(ca.khs[i], a.stok), ca.vls[i]));
        }
    }

    struct CNameRedeemFuzzingArgs {
        bool idx_idx;
        uint8 name_idx; string name1;
        uint8 to_idx; address to1;
        uint8 dur_idx; uint256 dur1;
        uint8 dl_idx; uint256 dl1;
        uint8 c_idx; bytes c1; uint8 c_name_idx;
        uint8 c_to_idx; uint8 c_dur_idx; uint8 c_dl_idx;
        uint8 c_chainid_idx; uint8 c_caddr_idx;
        uint8 c_sign_idx;
    }

    struct CNameRedeemArgs {
        uint idx;
        string name;
        address to;
        uint256 dur;
        uint256 dl;
        bytes c;
        uint256 stok;
    }

    function gen_c_nameRedeem(CNameRedeemFuzzingArgs memory fa)
        internal
        returns(CNameRedeemArgs memory a)
    {
        a.idx = fa.idx_idx ? 1 : 0;
        a.name = h_sel_word_alt(fa.name_idx, 125, fa.name1);
        a.to = h_sel_sender_alt(fa.to_idx, 200, fa.to1);

        // dur
        if (fa.dur_idx < 80) {
            // < c_min_reg_dur
            a.dur = fa.dur1 % _c_min_reg_dur[a.idx];
        }
        else if (fa.dur_idx < 160) {
            a.dur = _c_min_reg_dur[a.idx];
        }
        else {
            unchecked {
                a.dur = fa.dur1 + _c_min_reg_dur[a.idx];
            }
        }

        // dl
        if (fa.dl_idx < 80) {
            a.dl = fa.dl1 % block.timestamp;
        }
        else if (fa.dur_idx < 160) {
            a.dl = block.timestamp;
        }
        else {
            unchecked {
                a.dl = fa.dur1 + block.timestamp; // overflow
            }
        }

        //
        if (fa.c_idx < 200) {
            CNameRedeemArgs memory a1;

            a1.name = a.name; a1.to = a.to; a1.dur = a.dur; a1.dl = a.dl;
            if (fa.c_name_idx > 200) {
                bytes(a1.name)[0] = 'a'; }
            if (fa.c_to_idx   > 200) {
                a1.to = address(uint160(a1.to) ^ 1); }
            if (fa.c_dur_idx  > 200) {
                a1.dur ^= 1; }
            if (fa.c_dl_idx   > 200) {
                a1.dl  ^= 1; }

            uint chainid = block.chainid;
            address caddr = address(C[a.idx]);

            if (fa.c_chainid_idx > 200) {
                chainid ^= 1; }
            if (fa.c_caddr_idx   > 200) {
                caddr = address(uint160(caddr) ^ 1); }

            uint256 sk = SENDER_PK[h_sel_sender(fa.c_sign_idx)];

            bytes32 label = keccak256(bytes(a1.name));
            a.c = h_sign_hash(sk, keccak256(abi.encodePacked(label, a1.to, a1.dur, a1.dl, chainid, caddr)));
        }
        else {
            a.c = fa.c1;
        }

        a.stok = h_namehash(a.name, C_BASE_NODE[a.idx]);
    }

    function cons_c_nameRedeem(CNameRedeemArgs memory a) internal view returns(bool ok) {
        bool ok1 = false;
        if (block.timestamp < a.dl) {
            ok1 = true;
        }

        bool ok2 = false;
        bytes32 hash = keccak256(abi.encodePacked(keccak256(bytes(a.name)),
                                                  a.to,
                                                  a.dur,
                                                  a.dl,
                                                  block.chainid,
                                                  address(C[a.idx])));
        (address sa,) = hash.tryRecover(a.c);
        if (sa == _c_root[a.idx]) {
            ok2 = true;
        }
        if (_c_manager_set[a.idx].contains(sa)) {
            ok2 = true;
        }

        bool ok3 = false;
        if (_c_can_redeem[a.idx]) {
            ok3 = true;
        }

        bool ok4 = false;
        if (!_pns_owner_tbl.contains(a.stok) && (a.to != address(0))) {
            ok4 = true;
        }

        bool ok5 = false;
        if (address(C[a.idx]) == _pns_root) {
            ok5 = true;
        }
        if (_pns_manager_set.contains(address(C[a.idx]))) {
            ok5 = true;
        }

        ok = ok1 && ok2 && ok3 && ok4 && ok5;
    }

    function op_c_nameRedeem(CNameRedeemFuzzingArgs memory fa) public {
        // requirements
        // param generation
        CNameRedeemArgs memory a = gen_c_nameRedeem(fa);

        // update state
        bool ok = cons_c_nameRedeem(a);

        if (ok) {
            _pns_owner_tbl.set(a.stok, a.to);
            _pns_token_set.add(a.stok);
            _pns_sld_set.add(a.stok);
            _pns_sld_expire_tbl[a.stok] = a.dur + block.timestamp;
        }

        // call op
        uint256 ret =
            abi.decode(h_c_call_assert(ok, a.idx,
                                       abi.encodeWithSelector(C[a.idx].nameRedeem.selector,
                                                              a.name,
                                                              a.to,
                                                              a.dur,
                                                              a.dl,
                                                              a.c)),
                       (uint256));

        if (!ok) {
            return;
        }

        // assertion
        assert(ret == a.stok);
        assert(P.ownerOf(a.stok) == a.to);
        assert(P.expire(a.stok) == block.timestamp + a.dur);
        assert(P.origin(a.stok) == a.stok);
        assert(P.parent(a.stok) == a.stok);
        assert(!P.available(a.stok));
    }

    struct CRenewFuzzingArgs {
        bool idx_idx;
        uint8 name_idx; string name1;
        uint256 dur;
        uint8 value_idx; uint256 value1;
    }

    function cons_c_renew(uint idx, uint256 dur, uint256 value, uint256 price, uint256 stok)
        internal view
        returns(bool ok)
    {
        bool ok1 = false;
        if (_c_is_open[idx]) {
            ok1 = true;
        }

        bool ok2 = false;
        if (address(C[idx]) == _pns_root) {
            ok2 = true;
        }
        if (_pns_manager_set.contains(address(C[idx]))) {
            ok2 = true;
        }

        bool ok3 = false;
        if (_pns_sld_set.contains(stok)) {
            ok3 = true;
        }

        bool ok4 = false;
        if (value >= price) {
            ok4 = true;
        }

        bool ok5 = false;
        unchecked {
            if (_pns_sld_expire_tbl[stok] + dur + GRACE_PERIOD >
                _pns_sld_expire_tbl[stok] + GRACE_PERIOD) {
                ok5 = true;
            }
        }

        ok = ok1 && ok2 && ok3 && ok4 && ok5;
    }

    function op_c_renew(CRenewFuzzingArgs memory fa) public {
        // requirements
        // param generation
        uint idx = fa.idx_idx ? 1 : 0;
        string memory name = h_sel_word_alt(fa.name_idx, 200, fa.name1);
        uint256 dur = fa.dur;

        uint256 stok = h_namehash(name, C_BASE_NODE[idx]);

        string memory name_fixed = name;
        if (bytes(name).length == 0) {
            name_fixed = "1";
        }
        uint256 price = C[idx].renewPrice(name, dur);

        uint256 value;
        if (fa.value_idx < 80) {
            value = fa.value1 % price;
        }
        else if (fa.value_idx < 160) {
            value = price;
        }
        else {
            value = (price + fa.value1) % address(this).balance;
        }

        // update state
        bool ok = cons_c_renew(idx, dur, value, price, stok);

        if (ok) {
            _pns_sld_expire_tbl[stok] += dur;
        }

        // call op
        uint256 balance_root   = _c_root[idx].balance;
        uint256 balance_sender = msg.sender.balance;

        h_c_call_with_value_assert(ok, idx, value,
                                   abi.encodeWithSelector(C[idx].renew.selector,
                                                          name, dur));

        if (!ok) {
            return;
        }

        // assertion
        uint256 balance_root_new = _c_root[idx].balance;
        uint256 balance_sender_new = msg.sender.balance;

        assert(P.expire(stok) == _pns_sld_expire_tbl[stok]);
        assert(balance_root_new == balance_root + price);
        assert(balance_sender_new == balance_sender + value - price);
    }

    function op_c_renewByManager(bool idx_idx, uint8 name_idx, uint256 dur1) public {
        // requirements
        // param generation
        uint idx = idx_idx ? 1 : 0;
        string memory name = h_sel_word(name_idx);
        uint256 dur = dur1 % (5 * 365 days - 1 days + 1) + 1 days;

        uint256 stok = h_namehash(name, C_BASE_NODE[idx]);
        // update state
        bool ok1 = false;
        if (_c_is_live[idx]) {
            ok1 = true;
        }

        bool ok2 = false;
        if (msg.sender == _c_root[idx]) {
            ok2 = true;
        }
        if (_c_manager_set[idx].contains(msg.sender)) {
            ok2 = true;
        }

        bool ok3 = false;
        if (address(C[idx]) == _pns_root) {
            ok3 = true;
        }
        if (_pns_manager_set.contains(address(C[idx]))) {
            ok3 = true;
        }

        bool ok4 = false;
        if (_pns_sld_set.contains(stok)) {
            ok4 = true;
        }

        bool ok5 = false;
        unchecked {
            if (_pns_sld_expire_tbl[stok] + GRACE_PERIOD + dur >
                _pns_sld_expire_tbl[stok] + GRACE_PERIOD) {
                ok5 = true;
            }
        }

        bool ok = ok1 && ok2 && ok3 && ok4 && ok5;

        if (ok) {
            _pns_sld_expire_tbl[stok] += dur;
        }

        // call op
        h_c_call_assert(ok, idx, abi.encodeWithSelector(C[idx].renewByManager.selector,
                                                        name, dur));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.expire(stok) == _pns_sld_expire_tbl[stok]);
    }

    function cons_domain_modifiable(uint256 tok) internal view returns(bool) {
        bool ok1 = false;
        if (_pns_mutable) {
            ok1 = true;
        }

        bool ok2 = false;
        if (msg.sender == _pns_root) {
            ok2 = true;
        }
        if (_pns_manager_set.contains(msg.sender)) {
            ok2 = true;
        }
        if (h_pns_owner_is(tok, msg.sender)) {
            ok2 = true;
        }
        if (_pns_approve_tbl[tok] == msg.sender) {
            ok2 = true;
        }

        return ok1 && ok2;
    }

    function cons_p_setName(address addr, uint256 tok) internal view returns(bool) {
        bool ok1 = false;
        if (_pns_mutable) {
            ok1 = true;
        }

        bool ok2 = false;
        if ((msg.sender == _pns_root) || (_pns_manager_set.contains(msg.sender))) {
            ok2 = true;
        }

        bool own_tok = false;
        if (h_pns_owner_is(tok, msg.sender)) {
            own_tok = true;
        }
        if (_pns_approve_tbl[tok] == msg.sender) {
            own_tok = true;
        }

        bool own_addr = false;
        if (addr == msg.sender) {
            own_addr = true;
        }
        try Ownable(addr).owner() returns(address owner) {
            if (owner == msg.sender) {
                own_addr == true;
            }
        } catch {}

        if (own_tok && own_addr) {
            ok2 = true;
        }

        return ok1 && ok2;
    }

    function op_p_setName(uint8 addr_idx, address addr1,
                          uint8 tok_idx, uint256 tok1) public {

        // requirements
        // param generation
        address addr = addr1;
        if (addr_idx < 200) {
            addr = h_sel_sender_with_nft(addr_idx);
        }

        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // update state
        bool ok = cons_p_setName(addr, tok);

        if (ok) {
            _pns_info_name_tbl[addr] = tok;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setName.selector, addr, tok));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.getName(addr) == tok);
    }

    function op_p_setNftName(uint8 naddr_idx, address naddr1,
                             uint8 nid_idx, uint256 nid1,
                             uint8 tok_idx, uint256 tok1) public {
        // requirements
        // param generation
        address naddr = naddr1;
        if (naddr_idx < 100) {
            naddr = address(NFT[0]);
        }
        else if (naddr_idx < 200) {
            naddr = address(NFT[1]);
        }

        uint256 nid = nid1;
        if (nid_idx < 200) {
            nid = nid1 % 10;
        }

        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        address nowner = address(0);

        try IERC721(naddr).ownerOf(nid) returns(address owner) {
            nowner = owner;
        } catch {}

        // update state
        bool ok1 = false;
        if (cons_domain_modifiable(tok)) {
            ok1 = true;
        }

        bool ok2 = false;
        if (msg.sender == nowner) {
            ok2 = true;
        }
        try IERC721(naddr).getApproved(nid) returns(address ret) {
            if (ret == msg.sender) {
                ok2 = true;
            }
        } catch {}
        try IERC721(naddr).isApprovedForAll(nowner, msg.sender) returns(bool ret) {
            if (ret) {
                ok2 = true;
            }
        } catch {}

        bool ok = ok1 && ok2;

        if (ok) {
            _pns_info_nft_name_tbl[naddr][nid] = tok;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setNftName.selector,
                                                   naddr, nid, tok));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.getNftName(naddr, nid) == tok);
    }

    function op_p_addKeys(uint8[] memory keys_idx, string[] memory keys1) public {
        // requirements
        // param generation
        uint len = (keys1.length > keys_idx.length) ? keys_idx.length : keys1.length;
        string[] memory keys = new string[](len);

        for (uint i = 0; i < len; i++) {
            keys[i] = h_sel_word_alt(keys_idx[i], 200, keys1[i]);
        }

        // update state, no constraint
        for (uint i = 0; i < keys.length; i++) {
            uint256 hash = uint256(keccak256(bytes(keys[i])));
            _pns_key_tbl[hash] = keys[i];
        }

        // call op
        h_p_call_assert(true, abi.encodeWithSelector(P.addKeys.selector, keys));

        // assertion
        for (uint i = 0; i < keys.length; i++) {
            string memory key = keys[i];
            bytes32 hash = keccak256(bytes(key));

            assert(keccak256(bytes(P.getKey(uint256(hash)))) == hash);
        }
    }

    function op_p_setByHash(uint8 h_idx, uint256 h1,
                            string memory v,
                            uint8 tok_idx, uint256 tok1) public {
        // requirements
        // param generation
        uint256 h = h1;
        if (h_idx < 200) {
            h = uint256(keccak256(bytes(h_sel_word(h_idx))));
        }

        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // update state
        bool ok1 = false;
        if (cons_domain_modifiable(tok)) {
            ok1 = true;
        }

        bool ok2 = false;
        if (bytes(_pns_key_tbl[tok]).length > 0) {
            ok2 = true;
        }

        bool ok = ok1 && ok2;

        if (ok) {
            _pns_info_record_tbl[tok][h] = v;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setByHash.selector, h, v, tok));

        if (!ok) {
            return;
        }

        // assertion
        assert(h_str_eq(P.getByHash(h, tok), v));
    }

    function op_p_setManyByHash(uint8[] memory hs_idx, uint256[] memory hs1,
                                uint8 vs_idx, string[] memory vs1,
                                uint8 tok_idx, uint256 tok1) public {
        // requirements
        // param generation
        uint len = hs_idx.length;
        if (hs1.length < len) { len = hs1.length; }

        string[] memory vs = vs1;

        if (vs_idx < 200) { // all has equal len
            if (vs1.length < len) { len = vs1.length; }
            vs = new string[](len);
            for (uint i = 0; i < len; i++) { vs[i] = vs1[i]; }
        }

        uint256[] memory hs = new uint256[](len);
        for (uint i = 0; i < len; i++) {
            if (hs_idx[i] < 200) {
                hs[i] = uint256(keccak256(bytes(h_sel_word(hs_idx[i]))));
            }
            else {
                hs[i] = hs1[i];
            }
        }

        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // update state
        bool ok1 = false;
        if (cons_domain_modifiable(tok)) {
            ok1 = true;
        }

        bool ok2 = true;
        for (uint i = 0; i < hs.length; i++) {
            if (bytes(_pns_key_tbl[hs[i]]).length == 0) {
                ok2 = false;
            }
        }

        bool ok3 = false;
        if (hs.length == vs.length) {
            ok3 = true;
        }

        bool ok = ok1 && ok2 && ok3;

        if (ok) {
            for (uint i = 0; i < hs.length; i++) {
                _pns_info_record_tbl[tok][hs[i]] = vs[i];
            }
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setManyByHash.selector, hs, vs, tok));

        if (!ok) {
            return;
        }

        // assertion
        for (uint i = 0; i < hs.length; i++) {
            assert(h_str_eq(P.getByHash(hs[i], tok), vs[i]));
        }

        assert(h_str_ary_eq(P.getManyByHash(hs, tok), vs));
    }

    function op_p_setlink(uint8 tok_idx, uint256 tok1,
                          uint256 tgt, uint256 v) public {
        // requirements
        // param generation
        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // update state
        bool ok = cons_domain_modifiable(tok);

        if (ok) {
            _pns_info_link_tbl[tok][tgt] = v;
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setlink.selector, tok, tgt, v));

        if (!ok) {
            return;
        }

        // assertion
        assert(P.getlink(tok, tgt) == v);
    }

    function op_p_setlinks(uint8 tok_idx, uint256 tok1,
                           uint256[] memory tgts1,
                           uint8 vs_idx, uint256[] memory vs1) public {
        // requirements
        // param generation
        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        uint len = tgts1.length;

        uint256[] memory vs = vs1;
        if (vs_idx < 200) {
            if (vs1.length < len) {
                len = vs1.length;
            }

            vs = new uint256[](len);
            for (uint i = 0; i < len; i++) { vs[i] = vs1[i]; }
        }

        uint256[] memory tgts = new uint256[](len);
        for (uint i = 0; i < len; i++) { tgts[i] = tgts1[i]; }

        // update state
        bool ok1 = false;
        if (cons_domain_modifiable(tok)) {
            ok1 = true;
        }

        bool ok2 = false;
        if (vs.length == tgts.length) {
            ok2 = true;
        }

        bool ok = ok1 && ok2;

        if (ok) {
            for (uint i = 0; i < tgts.length; i++) {
                _pns_info_link_tbl[tok][tgts[i]] = vs[i];
            }
        }

        // call op
        h_p_call_assert(ok, abi.encodeWithSelector(P.setlinks.selector, tok, tgts, vs));

        if (!ok) {
            return;
        }

        // assertion
        for (uint i = 0; i < tgts.length; i++) {
            assert(P.getlink(tok, tgts[i]) == vs[i]);
        }

        assert(keccak256(abi.encodePacked(P.getlinks(tok, tgts))) ==
               keccak256(abi.encodePacked(vs)));
    }

    // ----------------------- permission check --------------------
    function chk_p_register(string memory name, address to, uint256 dur, uint256 base) public {
        // requirements
        // param generation
        // update state
        bool fail = true;

        if (msg.sender == _pns_root) {
            fail = false;
        }
        if (_pns_manager_set.contains(msg.sender)) {
            fail = false;
        }

        // call op
        (bool ok, ) = h_p_call(abi.encodeWithSelector(P.register.selector, name, to, dur, base));

        if (fail) {
            assert(!ok);
        }

        revert();
    }

    function chk_p_renew(uint8 id_idx, uint256 id1, uint256 dur) public {
        // requirements
        // param generation
        uint256 id = h_sel_token_alt(id_idx, 128, id1);

        // update state
        bool fail = true;

        if (msg.sender == _pns_root) {
            fail = false;
        }
        if (_pns_manager_set.contains(msg.sender)) {
            fail = false;
        }

        // call op
        (bool ok, ) = h_p_call(abi.encodeWithSelector(P.renew.selector, id, dur));

        if (fail) {
            assert(!ok);
        }

        revert();
    }

    // ----------------------- aux operation ------------------------
    function aop_pns_safeTransferFrom(uint8 to_idx, uint8 tok_idx) public {
        // param generation
        uint256 tok = h_sel_owned_token(tok_idx);
        address from = _pns_owner_tbl.get(tok);
        address to = h_sel_sender(to_idx);

        // update state
        _pns_owner_tbl.set(tok, to);

        // call op
        h_p_call(abi.encodeWithSignature("safeTransferFrom(address,address,uint256)",
                                         from, to, tok));

        // placeholder
        assert(1 < 2);
    }

    function aop_pns_approve(uint8 to_idx, uint8 tok_idx) public {
        // param generation
        uint256 tok = h_sel_owned_token(tok_idx);
        address to = h_sel_sender(to_idx);

        // update state
        _pns_approve_tbl[tok] = to;

        // call op
        h_p_call(abi.encodeWithSelector(P.approve.selector, tok, to));

        // placeholder
        assert(1 < 2);
    }

    function aop_nft_set_owner(bool idx, uint8 owner_idx) public {
        // param generation
        address owner = h_sel_sender(owner_idx);

        // update state & call op
        uint p_idx = idx ? 1 : 0;
        NFT[p_idx].transferOwnership(owner);

        // placeholder
        assert(1 < 2);
    }

    function aop_nft_transfer(bool idx, uint8 from_idx, uint8 to_idx, uint8 tok_idx) public {
        // param generation
        address from = h_sel_sender(from_idx);
        address to   = h_sel_sender(to_idx);
        uint256 tok  = tok_idx % 10;

        // update state & call op
        uint p_idx = idx ? 1 : 0;
        NFT[p_idx].safeTransferFrom(from, to, tok);

        // placeholder
        assert(1 < 2);
    }

    function aop_set_price(bool idx, int256 price) public {
        // requirements
        require(price > 0);

        // param generation

        // update state & call op
        uint p_idx = idx ? 1 : 0;
        PriceOracle(address(PRICE[p_idx])).updateAnswer(price);

        // placeholder
        assert(1 < 2);
    }

    // ------------------------ state check ------------------------
    function st_p_getName(uint8 addr_idx, address addr1) public view {
        // param generation
        address addr = addr1;

        if (addr_idx < 200) {
            addr = h_sel_sender_with_nft(addr_idx);
        }

        // assertion
        uint256 tok = _pns_info_name_tbl[addr];
        uint256 get = P.getName(addr);

        if (_pns_owner_tbl.contains(tok) &&
            (addr == _pns_owner_tbl.get(tok) ||
             addr == _pns_approve_tbl[tok])) {
            assert(get == tok);
        }
        else {
            assert(get == 0);
        }
    }

    function st_p_bounded(uint8 tok_idx, uint256 tok1) public view {
        // param generation
        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // assertion
        assert(P.bounded(tok) == _pns_bound_set.contains(tok));
    }

    function st_p_nameExpired(uint8 tok_idx, uint256 tok1) public view {
        // param generation
        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // assertion
        bool get = P.nameExpired(tok);

        if (_pns_sld_set.contains(tok)) {
            assert(get == (_pns_sld_expire_tbl[tok] + GRACE_PERIOD < block.timestamp));
        }
        else if (_pns_sd_set.contains(tok)) {
            assert(get == (_pns_sld_expire_tbl[_pns_sd_origin_tbl[tok]] + GRACE_PERIOD < block.timestamp));
        }
        else {
            assert(get == (GRACE_PERIOD < block.timestamp));
        }
    }

    function st_p_available(uint8 tok_idx, uint256 tok1) public view {
        // param generation
        uint256 tok = h_sel_token_alt(tok_idx, 200, tok1);

        // assertion
        assert(P.available(tok) == (_pns_sld_set.contains(tok) || _pns_sd_set.contains(tok)));
    }

    function st_c_totalRegisterPrice(bool idx_idx, string memory name, uint256 dur) public view {
        // param generation
        uint idx = idx_idx ? 1 : 0;

        uint l1 = _c_base_prices.length;
        if (bytes(name).length < l1) {
            l1 = bytes(name).length;
        }

        uint l2 = _c_rent_prices.length;
        if (bytes(name).length < l2) {
            l2 = bytes(name).length;
        }

        // avoid model fail, when implement will fail
        if (l1 == 0) {
            l1 = 1;
        }

        if (l2 == 0) {
            l2 = 1;
        }

        uint dollar_per_eth = h_get_price(idx);

        // assertion, use uint512 to avoid overflow
        Math512.uint512 memory cost = Math512.from(_c_rent_prices[idx][l2 - 1]);

        cost = cost.mul_nc(dur);
        cost = cost.add_io(_c_base_prices[idx][l1 - 1] * SECONDS_PER_YEAR); // assume here not overflow
        cost = cost.mul_nc(10**18).mul_nc(10**8);
        cost = cost.div128_dr(uint128(SECONDS_PER_YEAR));
        cost = cost.div128_dr(uint128(dollar_per_eth));

        if (cost.hi > 0) {
            assert(1 == 1);
        }

        uint256 get = C[idx].totalRegisterPrice(name, dur);

        assert(cost.hi == 0); // is cost.hi != 0, C[idx].totalRegisterPrice will revert
        assert(cost.lo == get);
    }

    function st_c_renewPrice(bool idx_idx, string memory name, uint256 dur) public view {
        // param generation
        uint idx = idx_idx ? 1 : 0;

        uint l = _c_rent_prices.length;
        if (bytes(name).length < l) {
            l = bytes(name).length;
        }

        // avoid model fail, when implement will fail
        if (l == 0) {
            l = 1;
        }

        uint dollar_per_eth = h_get_price(idx);

        // assertion
        Math512.uint512 memory cost = Math512.from(_c_rent_prices[idx][l - 1]);

        cost = cost.mul_nc(dur);
        cost = cost.mul_nc(10**18).mul_nc(10**8);
        cost = cost.div128_dr(uint128(SECONDS_PER_YEAR)).div128_dr(uint128(dollar_per_eth));

        if (cost.hi > 0) {
            assert(1 == 1);
        }

        uint256 get = C[idx].renewPrice(name, dur);

        assert(cost.hi == 0); // will fail if implement not revert
        assert(cost.lo == get);
    }
}
