// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPresale } from "./IPresale.sol";

interface IVesting {
  error bnb_not_supported();

  function initialize(
    IPresale presale,
    uint64 cliffPeriod,
    address beneficiary,
    uint256 _months,
    address owner
  ) external;
}
