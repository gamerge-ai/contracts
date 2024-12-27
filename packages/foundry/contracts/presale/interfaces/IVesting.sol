// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVesting {
    error bnb_not_supported();

    function initialize(uint64 tgeTrigerredAt, uint64 cliffPeriod, address beneficiary, uint64 durationSeconds) external;
}