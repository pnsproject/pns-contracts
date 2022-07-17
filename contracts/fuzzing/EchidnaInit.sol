// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../pns/PNS.sol";
import "../pns/PNSController.sol";
import "../MacroNFT.sol";

contract EchidnaInit {
using EnumerableSet for EnumerableSet.AddressSet;
using EnumerableSet for EnumerableSet.UintSet;
using EnumerableMap for EnumerableMap.UintToAddressMap;

// const
EnumerableSet.AddressSet    SENDER_POOL;
mapping(address => uint256) SENDER_PK;

uint256 GRACE_PERIOD = 31104000;

PNS P                          = PNS(0x7Bf7bb74C43dc141293aFf12A2D7DE350E9b09E0);
Controller[2] C                = [Controller(0x6346e3A22D2EF8feE3B3c2171367490e52d81C52), Controller(0xAA86dDA78E9434acA114b6676Fc742A18d15a1CC)];
MacroNFT[2] NFT                = [MacroNFT(0x1dC4c1cEFEF38a777b15aA20260a54E584b16C48), MacroNFT(0x1D7022f5B17d2F8B695918FB48fa1089C9f85401)];
AggregatorV3Interface[2] PRICE = [AggregatorV3Interface(0x7e3f4E1deB8D3A05d9d2DA87d9521268D0Ec3239), AggregatorV3Interface(0x04B5dAdd2c0D6a261bfafBc964E0cAc48585dEF3)];

uint256[2] C_BASE_NODE = [0x3fce7d1364a893e213bc4212792b517ffc88f5b13b86c8ef9c8d390c3a1370ce, 0xac2c11ea5d4a4826f418d3befbf0537de7f13572d2a433edfe4a7314ea5dc896];

// pns var
address _pns_root;
EnumerableSet.AddressSet       _pns_manager_set;
EnumerableMap.UintToAddressMap _pns_owner_tbl;
EnumerableSet.UintSet          _pns_token_set;

// controller val
address[2] _c_root;
EnumerableSet.AddressSet[2] _c_manager_set;
AggregatorV3Interface[2] _c_price_feed;
uint256[][2] _c_base_prices;
uint256[][2] _c_rent_prices;

constructor() {
SENDER_POOL.add(0x5409ED021D9299bf6814279A6A1411A7e866A631);
SENDER_POOL.add(0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb);
SENDER_POOL.add(0xE36Ea790bc9d7AB70C55260C66D52b1eca985f84);

SENDER_PK[0x5409ED021D9299bf6814279A6A1411A7e866A631] = 0xf2f48ee19680706196e2e339e5da3491186e0c4c5030670656b0e0164837257d;
SENDER_PK[0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb] = 0x5d862464fe9303452126c8bc94274b8c5f9874cbd219789b3eb2128075a76f72;
SENDER_PK[0xE36Ea790bc9d7AB70C55260C66D52b1eca985f84] = 0xdf02719c4df8b9b8ac7f551fcb5d9ef48fa27eef7a66453879f4d8fdc6e78fb1;

_pns_root = 0x5409ED021D9299bf6814279A6A1411A7e866A631;

_pns_manager_set.add(0x5409ED021D9299bf6814279A6A1411A7e866A631);
_pns_manager_set.add(0x6346e3A22D2EF8feE3B3c2171367490e52d81C52);
_pns_manager_set.add(0xAA86dDA78E9434acA114b6676Fc742A18d15a1CC);

_pns_owner_tbl.set(0x3fce7d1364a893e213bc4212792b517ffc88f5b13b86c8ef9c8d390c3a1370ce, 0x6346e3A22D2EF8feE3B3c2171367490e52d81C52);
_pns_owner_tbl.set(0xac2c11ea5d4a4826f418d3befbf0537de7f13572d2a433edfe4a7314ea5dc896, 0xAA86dDA78E9434acA114b6676Fc742A18d15a1CC);

_pns_token_set.add(0x3fce7d1364a893e213bc4212792b517ffc88f5b13b86c8ef9c8d390c3a1370ce);
_pns_token_set.add(0xac2c11ea5d4a4826f418d3befbf0537de7f13572d2a433edfe4a7314ea5dc896);

// Controller 0
_c_root[0] = 0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb;
_c_manager_set[0].add(0x6Ecbe1DB9EF729CBe972C83Fb886247691Fb6beb);
_c_price_feed[0] = AggregatorV3Interface(0x7e3f4E1deB8D3A05d9d2DA87d9521268D0Ec3239);

_c_base_prices[0] = new uint256[](6);
_c_base_prices[0][0] = 2000;
_c_base_prices[0][1] = 2000;
_c_base_prices[0][2] = 2000;
_c_base_prices[0][3] = 200;
_c_base_prices[0][4] = 200;
_c_base_prices[0][5] = 20;

_c_rent_prices[0] = new uint256[](5);
_c_rent_prices[0][0] = 500;
_c_rent_prices[0][1] = 400;
_c_rent_prices[0][2] = 300;
_c_rent_prices[0][3] = 100;
_c_rent_prices[0][4] = 5;

// Controller 1
_c_root[1] = 0xE36Ea790bc9d7AB70C55260C66D52b1eca985f84;
_c_manager_set[1].add(0xE36Ea790bc9d7AB70C55260C66D52b1eca985f84);
_c_price_feed[1] = AggregatorV3Interface(0x04B5dAdd2c0D6a261bfafBc964E0cAc48585dEF3);

_c_base_prices[1] = new uint256[](5);
_c_base_prices[1][0] = 5000;
_c_base_prices[1][1] = 2500;
_c_base_prices[1][2] = 1250;
_c_base_prices[1][3] = 10;
_c_base_prices[1][4] = 5;

_c_rent_prices[1] = new uint256[](6);
_c_rent_prices[1][0] = 300;
_c_rent_prices[1][1] = 200;
_c_rent_prices[1][2] = 100;
_c_rent_prices[1][3] = 50;
_c_rent_prices[1][4] = 30;
_c_rent_prices[1][5] = 20;


}
}