// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {VestingWallet, VestingWalletCliff} from "@openzeppelin/contracts/finance/VestingWalletCliff.sol";

contract Vesting is VestingWalletCliff {
    constructor() VestingWalletCliff(12333) VestingWallet(address(1), 212312, 23131) {}
}
