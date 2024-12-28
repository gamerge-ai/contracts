// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IPresale } from "./interfaces/IPresale.sol";
import "./interfaces/IVesting.sol";
import { ERC1967Proxy } from
  "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from
  "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from
  "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from
  "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from
  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AggregatorV3Interface } from
  "@chainlink/brownie/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { PresaleFactory } from "./PresaleFactory.sol";

contract Presale is
  IPresale,
  Ownable2StepUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  using SafeERC20 for IERC20;

  /// @notice Maximum purchase amount per address during presale (in USD)
  uint48 public constant MAX_PURCHASE_LIMIT = 1000 * 1e6;
  /// @notice Referral bonus percentage
  uint8 public constant REFERRAL_BONUS = 10; // 10% referral bonus
  /// @notice bps for accurate decimals
  uint16 private constant BPS = 100; // 1% = 100 points

  /// @notice reference to the GMG ERC20 token
  IERC20 public gmg;
  /// @notice reference to the USDT ERC20 token
  IERC20 private _usdt;

  /// @notice struct holding all the info about this presale round
  PresaleInfo public presaleInfo;

  /// @notice address of the Factory contract that deployed this presale (will be same for every presale)
  PresaleFactory public presaleFactory;

  /// @notice amount of GMG bought so far
  uint256 public gmgBought;
  AggregatorV3Interface public bnbPriceAggregator;

  /// @notice TGE info;
  uint64 public tgeTriggeredAt;
  bool public isTgeTriggered;

  /// @notice Mapping to store participant details
  mapping(address => Participant) public participantDetails;
  /// @notice Mappings to store referral details
  mapping(address => uint256) public individualReferralBnb;
  mapping(address => uint256) public individualReferralUsdt;
  /// @notice Mapping to store the vesting wallet addresses
  mapping(address => IVesting) public vestingWallet;

  bool public isPresaleStarted;

  modifier afterTgeTrigger() {
    if (!isTgeTriggered) revert tge_not_triggered();
    _;
  }

  modifier presaleStarted() {
    if (!isPresaleStarted) revert presale_is_stopped();
    _;
  }

  modifier onlyOwnerOrFactory() {
    if (msg.sender != owner() && msg.sender != address(presaleFactory)) {
      revert only_owner_or_factory();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    uint16 _tokenPrice,
    uint88 _tokenAllocation,
    uint24 _cliff,
    uint8 _vestingMonths,
    uint8 _tgePercentages,
    uint8 _presaleStage,
    address _bnbPriceAggregator,
    address _gmgAddress,
    address _usdtAddress,
    address _gmgRegistryAddress,
    address _owner
  ) external override initializer {
    __Ownable_init(_owner);
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();

    presaleFactory = PresaleFactory(_gmgRegistryAddress);

    presaleInfo = PresaleInfo(
      _tokenPrice,
      _tokenAllocation,
      _cliff,
      _vestingMonths,
      _tgePercentages,
      _presaleStage
    );

    bnbPriceAggregator = AggregatorV3Interface(_bnbPriceAggregator);

    gmg = IERC20(_gmgAddress);
    _usdt = IERC20(_usdtAddress);
  }

  /*
   --------------------------
   ----------EXTERNAL OPEN FUNCTIONS----------
   --------------------------
   */

  function buyWithBnb(
    address referral
  ) public payable override nonReentrant presaleStarted {
    address participant = msg.sender;
    uint256 decimals = bnbPriceAggregator.decimals() - 6;
    (, int256 latestPrice,,,) = bnbPriceAggregator.latestRoundData();
    uint256 bnbInUsd = uint256(latestPrice) / (10 ** decimals);
    uint256 valueInUsd = (bnbInUsd * (msg.value)) / 1e18;

    _buyLogic(participant, referral, valueInUsd, ASSET.BNB);
  }

  function buyWithUsdt(
    uint256 usdtAmount,
    address referral
  ) external override nonReentrant presaleStarted {
    address participant = msg.sender;

    _buyLogic(participant, referral, usdtAmount, ASSET.USDT);

    _usdt.safeTransferFrom(participant, address(this), usdtAmount);
  }

  function claimTGE(
    address _participant
  ) external override nonReentrant afterTgeTrigger {
    if (msg.sender != _participant && msg.sender != owner()) {
      revert only_participant_or_owner();
    }

    Participant storage participant = participantDetails[_participant];

    if (!participant.isParticipant) revert not_a_participant();

    uint256 claimableGMG = participantDetails[_participant].releaseOnTGE;

    if (claimableGMG == 0) revert cannot_claim_zero_amount();

    participant.releaseOnTGE = 0;

    gmg.safeTransfer(_participant, claimableGMG);

    emit TgeClaimed(_participant, claimableGMG, msg.sender == owner());
  }

  function claimRefferalAmount(
    ASSET asset
  ) external override nonReentrant {
    if (asset == ASSET.BNB) {
      (bool success,) =
        msg.sender.call{ value: individualReferralBnb[msg.sender] }("");
      if (!success) revert referral_withdrawal_failed();
    } else {
      _usdt.safeTransfer(msg.sender, individualReferralUsdt[msg.sender]);
    }
  }

  /*
   --------------------------
   ----------EXTERNAL RESTRICTED FUNCTIONS----------
   --------------------------
   */
  function triggerTGE() external override onlyOwnerOrFactory {
    if (isTgeTriggered) revert tge_already_triggered();

    tgeTriggeredAt = uint64(block.timestamp);
    isTgeTriggered = true;

    emit TgeTriggered(tgeTriggeredAt, isTgeTriggered);
  }

  function recoverFunds(
    ASSET asset,
    IERC20 token,
    address to,
    uint256 amount
  ) external override onlyOwner nonReentrant {
    if (asset == ASSET.BNB) {
      (bool success,) = to.call{ value: amount }("");
      require(success, "recovery failed");
      emit BnbRecoverySuccessful(to, amount);
    } else if (asset == ASSET.USDT) {
      _usdt.safeTransfer(to, amount);
      emit RecoverySuccessful(_usdt, to, amount);
    } else {
      token.safeTransfer(to, amount);
      emit RecoverySuccessful(token, to, amount);
    }
  }

  function startPresale() external override onlyOwnerOrFactory {
    if (isPresaleStarted) revert presale_already_started();

    isPresaleStarted = true;

    emit PresaleStarted(presaleInfo.presaleStage);
  }

  function stopPresale() external override onlyOwnerOrFactory {
    if (!isPresaleStarted) revert presale_already_stopped();

    isPresaleStarted = false;

    emit PresaleStopped(presaleInfo.presaleStage);
  }

  /*
   --------------------------
   ----------UPGRADE RESTRICTION----------
   --------------------------
   */
  function _authorizeUpgrade(
    address newImplementation
  ) internal override onlyOwner { }

  /*
   --------------------------
   ----------VIEW FUNCTIONS----------
   --------------------------
   */
  function calculateReferralAmount(
    uint256 amountInUsdtOrBnb
  ) public pure override returns (uint256 amountToReferral) {
    amountToReferral =
      (amountInUsdtOrBnb * (REFERRAL_BONUS * BPS)) / (100 * BPS);
  }

  /*
   --------------------------
   ----------HELPER PRIVATE FUNCTIONS----------
   --------------------------
   */

  function _buyLogic(
    address _participant,
    address _referral,
    uint256 valueInUsd,
    ASSET asset
  ) private {
    if (
      presaleFactory.getTotalBought(_participant) + valueInUsd
        > MAX_PURCHASE_LIMIT
    ) revert max_limit_exceeded();

    presaleFactory.updateTotalBought(_participant, valueInUsd);

    uint256 gmgAmount = valueInUsd / presaleInfo.pricePerToken;

    uint256 gmgB = gmgBought;
    if (gmgB + gmgAmount > presaleInfo.allocation) {
      revert total_gmg_sold_out(presaleInfo.allocation - gmgB);
    }
    if (gmgAmount > gmg.balanceOf(address(this))) {
      revert presale_ran_out_of_gmg();
    }
    gmgBought += gmgAmount;

    // stop the presale if bought amount has reached allocation amount
    if (gmgBought == presaleInfo.allocation) isPresaleStarted = false;

    _updateReferral(_referral, asset, msg.value);
    _createVestingWallet(_participant);

    Participant storage participant = participantDetails[_participant];
    if (!participant.isParticipant) {
      participant.isParticipant = true;
    }
    participant.totalGMG += gmgAmount;
    uint256 releaseOnTGE =
      (gmgAmount * (presaleInfo.tgePercentage * BPS)) / (100 * BPS);
    participant.releaseOnTGE += releaseOnTGE;

    if (asset == ASSET.BNB) {
      emit BoughtWithBnb(_participant, msg.value, gmgAmount);
    } else {
      emit BoughtWithUsdt(_participant, valueInUsd, gmgAmount);
    }
  }

  function _updateReferral(
    address referral,
    ASSET asset,
    uint256 amount
  ) private {
    if (referral != address(0)) {
      uint256 amountToReferral = calculateReferralAmount(amount);

      if (asset == ASSET.BNB) {
        individualReferralBnb[referral] += amountToReferral;
      } else {
        individualReferralUsdt[referral] += amountToReferral;
      }
    }
  }

  function _createVestingWallet(
    address _participant
  ) private {
    if (address(vestingWallet[_participant]) == address(0)) {
      IVesting newVestingWallet = IVesting(
        address(new ERC1967Proxy(address(presaleFactory.vestingImpl()), ""))
      );
      newVestingWallet.initialize(
        tgeTriggeredAt,
        presaleInfo.cliffPeriod,
        _participant,
        presaleInfo.vestingMonths * 30 days,
        owner()
      );

      vestingWallet[_participant] = newVestingWallet;

      emit VestingWalletCreated(_participant, newVestingWallet);
    }
  }

  receive() external payable {
    buyWithBnb(address(0));
  }
}
