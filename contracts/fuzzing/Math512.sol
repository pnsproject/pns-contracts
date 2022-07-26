// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Math512 {
    struct uint512 {
        uint256 hi;
        uint256 lo;
    }

    function from(uint256 lo) pure internal returns(uint512 memory res) {
        res.hi = 0;
        res.lo = lo;
    }

    // NOTE, ignore overflow
    function add_io(uint512 memory a, uint256 b) pure internal returns(uint512 memory res) {
        res.hi = a.hi;

        unchecked {
            res.lo = a.lo + b;
            if (res.lo < a.lo) {
                res.hi += 1;
            }
        }
    }

    // NOTE: ignore underflow
    function sub_iu(uint512 memory a, uint256 b) pure internal returns(uint512 memory res) {
        res.hi = a.hi;

        unchecked {
            res.lo = a.lo - b;
            if (res.lo > a.lo) {
                res.hi -= 1;
            }
        }
    }

    uint256 constant MASK128 = 2 ** 128 - 1;

    // NOTE: here ci is pre accumulation of co, not from previous stage
    function _add3(uint256 x, uint256 y, uint256 z, uint256 ci) pure internal returns(uint256 s, uint256 co) {
        s = x;
        co = ci;

        unchecked {
            if (s + y < s) { co++; }
            s += y;
            if (s + z < s) { co++; }
            s += z;
        }
    }

    struct _uint_by_128 {
        uint256 _4;
        uint256 _3;
        uint256 _2;
        uint256 _1;
        uint256 _0;
    }

    function mul(uint512 memory x, uint256 b) pure internal returns(uint512 memory res, uint256 carry) {
        // split 128bit interger
        _uint_by_128 memory a;

        a._3 = x.hi >> 128;
        a._2 = x.hi & MASK128;
        a._1 = x.lo >> 128;
        a._0 = x.lo & MASK128;

        uint256 b_1 = b >> 128;
        uint256 b_0 = b & MASK128;

        //  |  768  | 512   | 256   |
        //  +-------+-------+-------+
        //  |  d_4  |       |       |
        //      |  c_3  |   |       |
        //      |  d_3  |   |       |
        //          |  c_2  |       |
        //          |  d_2  |       |
        //              |  c_1  |   |
        //              |  d_1  |   |
        //                  |  c_0  |

        _uint_by_128 memory c; // c._4 not use
        c._0 = a._0 * b_0;
        c._1 = a._1 * b_0;
        c._2 = a._2 * b_0;
        c._3 = a._3 * b_0;

        _uint_by_128 memory d; // d._0 not use
        d._1 = a._0 * b_1;
        d._2 = a._1 * b_1;
        d._3 = a._2 * b_1;
        d._4 = a._3 * b_1;

        // low bit, 0~255
        uint256 cry_2 = (c._1 >> 128) + (d._1 >> 128);
        uint256 lo;
        (lo, cry_2) = _add3(c._0, (c._1 & MASK128) << 128, (d._1 & MASK128) << 128, cry_2);

        // high bit, 256~511
        uint256 cry_4 = (c._3 >> 128) + (d._3 >> 128);
        uint256 hi;
        (hi, cry_4) = _add3(c._2, d._2, cry_2, cry_4);
        (hi, cry_4) = _add3(hi, (c._3 & MASK128) << 128, (d._3 & MASK128) << 128, cry_4);

        // res
        res.lo = lo;
        res.hi = hi;

        // carry
        carry = d._4 + cry_4;
    }

    // mul, ensure no carry
    function mul_nc(uint512 memory a, uint256 b) pure internal returns(uint512 memory res) {
        uint256 c;
        (res, c) = mul(a, b);
        assert(c == 0);
    }

    function div128(uint512 memory x, uint128 b) pure internal returns(uint512 memory quo, uint128 rem) {
        // split 128bit interger
        _uint_by_128 memory a;

        a._3 = x.hi >> 128;
        a._2 = x.hi & MASK128;
        a._1 = x.lo >> 128;
        a._0 = x.lo & MASK128;

        uint256 c = uint256(b);

        _uint_by_128 memory q;
        q._3 = a._3 / c;
        a._2 += (a._3 % c) << 128;
        q._2 = a._2 / c;
        a._1 += (a._2 % c) << 128;
        q._1 = a._1 / c;
        a._0 += (a._1 % c) << 128;
        q._0 = a._0 / c;

        rem = uint128(a._0 % c);

        quo.hi = (q._3 << 128) + q._2;
        quo.lo = (q._1 << 128) + q._0;
    }

    // div, drop remainder
    function div128_dr(uint512 memory a, uint128 b) pure internal returns(uint512 memory quo) {
        (quo,) = div128(a, b);
    }
}
