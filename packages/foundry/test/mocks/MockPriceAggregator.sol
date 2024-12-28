// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockPriceAggregator {
  int256 private price = 3000e8; // $3000 with 8 decimals

  function decimals() external pure returns (uint8) {
    return 8;
  }

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    )
  {
    return (1, price, block.timestamp, block.timestamp, 1);
  }

  function setPrice(
    int256 _price
  ) external {
    price = _price;
  }
}
