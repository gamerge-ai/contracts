// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IVesting.sol";

interface IPresale {
  enum ASSET {
    OTHER,
    BNB,
    USDT
  }

  /*
    --------------------------
    ----------STRUCTS----------
    --------------------------
    */
  /// @notice Details of single presale stage
  struct PresaleInfo {
    uint256 pricePerToken;
    uint256 allocation;
    uint64 cliffPeriod;
    uint8 vestingMonths;
    uint8 tgePercentage;
    uint8 presaleStage;
  }
  /// @notice Details of user purchase and vesting progress

  struct Participant {
    uint256 totalGMG; // Total GMG bought so far
    uint256 releaseOnTGE; // GMG amount to be released after TGE
    bool isParticipant;
  }

  struct InitParams {
    uint256 tokenPrice;
    uint256 tokenAllocation;
    uint64 cliff;
    uint8 vestingMonths;
    uint8 tgePercentages;
    uint8 presaleStage;
    address bnbPriceAggregator;
    address gmgAddress;
    address usdtAddress;
    address presaleFactory;
    address owner;
  }

  /*
    --------------------------
    ----------ERRORS----------
    --------------------------
    */

  error max_limit_exceeded();
  error presale_ran_out_of_gmg();
  error only_participant_or_owner();
  error only_owner_or_factory();
  error tge_already_triggered();
  error tge_not_triggered();
  error cliff_period_not_ended();
  error not_a_participant();
  error nothing_to_claim();
  error everything_has_claimed();
  error referral_withdrawal_failed();
  error cannot_claim_zero_amount();
  error presale_is_stopped();
  error presale_already_started();
  error presale_already_stopped();
  error total_gmg_sold_out(uint256 gmgLeft);
  error stale_chainlink_price(uint priceSecondsAgo);
  error invalid_chainlink_price();

  /*
    --------------------------
    ----------EVENTS----------
    --------------------------
    */

  event PresaleStarted(uint8 indexed presaleStage);
  event PresaleStopped(uint8 indexed presaleStage);
  event BoughtWithBnb(
    address indexed buyer, uint256 amountInBnb, uint256 gmgTokens
  );
  event BoughtWithUsdt(
    address indexed buyer, uint256 amountInUsdt, uint256 gmgTokens
  );
  event TgeTriggered(uint256 triggeredAt, bool isTriggered);
  event TgeClaimed(
    address indexed claimedTo, uint256 amountClaimed, bool claimedByOwner
  );
  event VestingTokensClaimed(
    address indexed withdrawnTo,
    uint256 amountWithdrawn,
    bool withdrawnByOwner,
    uint256 remainingAmount
  );
  event BnbRecoverySuccessful(address indexed to, uint256 amount);
  event RecoverySuccessful(
    IERC20 indexed token, address indexed to, uint256 amount
  );
  event VestingWalletCreated(
    address indexed participant, IVesting indexed vesting
  );

  /*
    --------------------------
    ----------FUNCTIONS----------
    --------------------------
    */

  function initialize(
    InitParams calldata params
  ) external;

  // EXTERNAL OPEN FUNCTIONS
  function buyWithBnb(
    address referral
  ) external payable;
  function buyWithUsdt(uint256 usdtAmount, address referral) external;
  function claimTGE(
    address _participant
  ) external;
  function claimRefferalAmount(
    ASSET asset
  ) external;

  // EXTERNAL RESTRICTED FUNCTIONS
  function triggerTGE() external;
  function recoverFunds(
    ASSET asset,
    IERC20 token,
    address to,
    uint256 amount
  ) external;
  function startPresale() external;
  function stopPresale() external;

  // VIEW FUNCTIONS
  function calculateReferralAmount(
    uint256 amountInUsdtOrBnb
  ) external pure returns (uint256 amountToReferral);
  function isPresaleStarted() external returns (bool);
  function isTgeTriggered() external returns (bool);
  function tgeTriggeredAt() external view returns (uint64);
}
