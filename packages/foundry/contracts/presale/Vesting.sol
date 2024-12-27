// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2StepUpgradeable, OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {VestingWalletUpgradeable} from "@openzeppelin/contracts-upgradeable/finance/VestingWalletUpgradeable.sol";
import "./interfaces/IVesting.sol";

contract Vesting is IVesting, Ownable2StepUpgradeable, VestingWalletUpgradeable {

    uint64 private _tgeTrigerredAt;
    uint64 private _cliffPeriod;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint64 tgeTrigerredAt_, uint64 cliffPeriod_, address _beneficiary, uint64 _durationSeconds) external override initializer {
        __Ownable_init(_beneficiary);
        // passing 0 as the `startTimestamp` as its not going to be used in the vesting logic
        __VestingWallet_init_unchained(_beneficiary, 0, _durationSeconds);

        _tgeTrigerredAt = tgeTrigerredAt_;
        _cliffPeriod = cliffPeriod_;
    }

    function start() public view override returns (uint256 startTimestamp) {
        startTimestamp = _tgeTrigerredAt + _cliffPeriod;
    }

    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view override returns (uint256) {
        if (_tgeTrigerredAt == 0) return 0;

        return super._vestingSchedule(totalAllocation, timestamp);
    }

    /*
   --------------------------
   ----------TURNING OFF BNB SUPPORT----------
   --------------------------
   */

    function released() public pure override returns (uint256) {
        revert bnb_not_supported();
    }
    
    function releasable() public pure override returns (uint256) {
        revert bnb_not_supported();
    }

    function release() public pure override {
        revert bnb_not_supported();
    }

    function vestedAmount(uint64) public pure override returns (uint256) {
        revert bnb_not_supported();
    }

    receive() external payable override {
        revert bnb_not_supported();
    }

    /*
   --------------------------
   ----------REQUIRED OVERRIDES----------
   --------------------------
   */
    function transferOwnership(address newOwner) public override(OwnableUpgradeable, Ownable2StepUpgradeable) onlyOwner {
        super.transferOwnership(newOwner); // this?
        // Ownable2StepUpgradeable.transferOwnership(newOwner); // or this?
    }

    function _transferOwnership(address newOwner) internal override(OwnableUpgradeable, Ownable2StepUpgradeable) {
        super._transferOwnership(newOwner);
    }
}
