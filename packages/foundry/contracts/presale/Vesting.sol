// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OwnableUpgradeable } from
  "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from
  "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { VestingWalletUpgradeable } from
  "@openzeppelin/contracts-upgradeable/finance/VestingWalletUpgradeable.sol";
import "./interfaces/IVesting.sol";
import "./interfaces/IPresale.sol";

contract Vesting is IVesting, VestingWalletUpgradeable, UUPSUpgradeable {
  address private _owner;
  IPresale private _presale;
  uint64 private _cliffPeriod;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    IPresale presale,
    uint64 cliffPeriod_,
    address _beneficiary,
    uint256 _months,
    address owner_
  ) external override initializer {
    __Ownable_init(_beneficiary);
    // passing 0 as the `startTimestamp` as its not going to be used in the vesting logic
    __VestingWallet_init_unchained(_beneficiary, 0, uint64(_months * 30 days));

    _owner = owner_;
    _presale = presale;
    _cliffPeriod = cliffPeriod_;
  }

  function start() public view override returns (uint256 startTimestamp) {
    startTimestamp = _presale.tgeTriggeredAt() + _cliffPeriod;
  }

  function _vestingSchedule(
    uint256 totalAllocation,
    uint64 timestamp
  ) internal view override returns (uint256) {
    if (_presale.tgeTriggeredAt() == 0) return 0;

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

  function vestedAmount(
    uint64
  ) public pure override returns (uint256) {
    revert bnb_not_supported();
  }

  receive() external payable override {
    revert bnb_not_supported();
  }

  /*
    --------------------------
    ----------UPGRADE RESTRICTION----------
    --------------------------
    */
  function _authorizeUpgrade(
    address
  ) internal view override {
    require(msg.sender == _owner, "upgrade unauthorized");
  }
}
