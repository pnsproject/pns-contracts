// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../utils/RootOwnable.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";


contract PriceOracle is AggregatorV3Interface, ManagerOwnable, ERC2771Context {

  uint256 public constant override version = 0;
  uint8 public override decimals;

  int256 public latestAnswer;
  uint256 public latestTimestamp;
  uint256 public latestRound;

  mapping(uint256 => int256) public getAnswer;
  mapping(uint256 => uint256) public getTimestamp;
  mapping(uint256 => uint256) private getStartedAt;

  constructor(int256 _answer, address forwarder) ERC2771Context(forwarder) {
    decimals = 8;
    updateAnswer(_answer);
  }

  function _msgSender() internal view virtual
      override(ERC2771Context, Context) returns (address) {
      return super._msgSender();
  }

  function _msgData() internal view virtual
      override(ERC2771Context, Context) returns (bytes calldata) {
      return super._msgData();
  }


  function updateAnswer(int256 _answer) public onlyManager {
    latestAnswer = _answer;
    latestTimestamp = block.timestamp;
    latestRound++;
    getAnswer[latestRound] = _answer;
    getTimestamp[latestRound] = block.timestamp;
    getStartedAt[latestRound] = block.timestamp;
  }

  function getRoundData(uint80 _roundId)
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
  }

  function latestRoundData()
    external
    view
    override
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (
      uint80(latestRound),
      getAnswer[latestRound],
      getStartedAt[latestRound],
      getTimestamp[latestRound],
      uint80(latestRound)
    );
  }

  function description() external pure override returns (string memory) {
    return "";
  }

}
