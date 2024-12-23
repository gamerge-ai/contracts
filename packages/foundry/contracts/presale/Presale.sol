// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IPresale} from "./IPresale.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/brownie/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PresaleFactory} from "./PresaleFactory.sol";


contract Presale is IPresale, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    
    /// @notice Maximum purchase amount per address during presale (in USD)
    uint48 public constant MAX_PURCHASE_LIMIT = 1000 * 1e6;
    /// @notice Referral bonus percentage
    uint8 public constant REFERRAL_BONUS = 10; // 10% referral bonus
    /// @notice bps for accurate decimals
    uint16 private constant BPS = 100; // 1% = 100 points

    PresaleInfo public presaleInfo;

    /// @notice Mapping to store participant details
    mapping(address => Participant) public participantDetails;
    /// @notice Mapping to store referral details
    mapping(address => uint256) public individualReferralAmount;

    /// @notice Start time of the presale
    uint256 public presaleStartTime;
    /// @notice total bnb
    uint256 public totalBnb;
    /// @notice total usdt
    uint256 public totalUsdt;
    /// @notice tge triggered time;
    uint256 public tgeTriggeredAt;

    bool public isTgeTriggered = false;

    /// @notice Initializes the Chainlink or Oracle price aggregator interface for ETH prices.
    AggregatorV3Interface public bnbPriceAggregator;

    /// @notice reference to the GMG ERC20 token 
    IERC20 private _gmg;
    /// @notice reference to the USDT ERC20 token
    IERC20 private _usdt;

    PresaleFactory private gmgRegistry;

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
        address _bnbPriceAggregator, 
        address _gmgAddress, 
        address _usdtAddress,
        address _gmgRegistryAddress,
        address _owner
        ) external initializer {
            __Ownable_init(_owner);

        gmgRegistry = PresaleFactory(_gmgRegistryAddress);
        presaleInfo = PresaleInfo(_tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages);
        bnbPriceAggregator = AggregatorV3Interface(_bnbPriceAggregator);
        _gmg = IERC20(_gmgAddress);
        _usdt = IERC20(_usdtAddress);
        presaleStartTime = block.timestamp;
        emit PresaleStarted(presaleStartTime);

    }

    function _limitExceeded(address user, uint256 amount) view private {
        if(gmgRegistry.getTotalBought(user) + amount > MAX_PURCHASE_LIMIT) revert max_limit_exceeded();
    }

    function getIndividualBoughtAmount() public view returns(uint256) {
        return gmgRegistry.getTotalBought(msg.sender);
    }

    function _buyLogic(address _participant, uint256 valueInUsd, uint256 gmgTokens) private {
        Participant memory participant = participantDetails[_participant];
        if(!participant.isParticipant) {
            participant.isParticipant = true;
        }
        gmgRegistry.updateTotalBought(_participant, valueInUsd);
        participant.totalGMG += gmgTokens;
        uint256 releaseOnTGE = (gmgTokens * (presaleInfo.tgePercentage * BPS)) / (100 * BPS);
        participant.claimableVestedGMG += (gmgTokens - releaseOnTGE);
        participant.releaseOnTGE += releaseOnTGE;

        _gmg.transfer(_participant, gmgTokens);
    }

    function buyWithBnb(address referral) public nonReentrant payable {
        address participant = msg.sender;
        uint256 decimals = bnbPriceAggregator.decimals() - 6;
        (, int256 latestPrice , , ,)  = bnbPriceAggregator.latestRoundData();
        uint256 bnbInUsd = uint(latestPrice)/(10 ** decimals);
        uint256 valueInUsd = (bnbInUsd * (msg.value)) / 1e18;
        _limitExceeded(participant, valueInUsd);
        uint256 gmgTokens = valueInUsd/(presaleInfo.pricePerToken);
        if(gmgTokens > _gmg.balanceOf(address(this))) revert insufficient_tokens();

        uint256 amountToReferral;
        uint256 amountToContract;
        if(referral == address(0)) {
            amountToContract = msg.value;
        } else {
            amountToReferral = (msg.value * (10 * BPS)) / (100 * BPS);
            amountToContract = msg.value - amountToReferral;
            individualReferralAmount[referral] += amountToReferral;
            (bool success, ) = referral.call{value: amountToReferral}("");
            require(success, "BNB transfer failed to Referral");
        }
        totalBnb += amountToContract;
        _buyLogic(participant, valueInUsd, gmgTokens);

        emit BoughtWithBnb(participant, msg.value, gmgTokens);
    }

    function buyWithUsdt(uint256 usdtAmount, address referral) public nonReentrant {
        address participant = msg.sender;
        _limitExceeded(participant, usdtAmount);
        uint256 gmgTokens = usdtAmount / (presaleInfo.pricePerToken);
        if(gmgTokens > _gmg.balanceOf(address(this))) revert insufficient_tokens();
        bool success = _usdt.transferFrom(msg.sender, address(this), usdtAmount);
        require(success, "USDT transfer failed to Contract");

        uint256 amountToReferral;
        uint256 amountToContract;
        if(referral == address(0)) {
            amountToContract = usdtAmount;
        } else {
            amountToReferral = (usdtAmount * 10)/(100);
            amountToContract = usdtAmount - amountToReferral;
            individualReferralAmount[referral] += amountToReferral;
            bool referralSuccess = _usdt.transfer(referral, amountToReferral);
            require(referralSuccess, "USDT transfer failed to Referral");
        }
        totalUsdt += amountToContract;
        _buyLogic(participant, usdtAmount, gmgTokens);

        emit BoughtWithUsdt(participant, usdtAmount, gmgTokens);
    }

    function triggerTGE() public onlyOwner nonReentrant {
        // if(presaleStartTime.add(PresaleInfo.cliff) < block.timestamp) revert (""); // i am not sure when to trigger this
        if(isTgeTriggered) revert tge_already_triggered();
        tgeTriggeredAt = block.timestamp;
        isTgeTriggered = true;
        emit TgeTriggered(tgeTriggeredAt, isTgeTriggered);
    }

    function claimTGE(address _participant) public nonReentrant {
        if(msg.sender == _participant || msg.sender == owner()) revert only_participant_or_owner();
        Participant memory participant = participantDetails[_participant];
        if(!participant.isParticipant) revert not_a_participant();
        if(!isTgeTriggered) revert tge_not_triggered();
        uint256 claimableGMG = participantDetails[_participant].releaseOnTGE;
        participant.releaseOnTGE = 0;
        participant.withdrawnGMG += claimableGMG;
        _gmg.transfer(_participant, claimableGMG);
        emit TgeClaimed(_participant, claimableGMG, msg.sender == owner());
    }

    function claimVestingAmount(address _participant) public nonReentrant {
        if(msg.sender == _participant || msg.sender == owner()) revert only_participant_or_owner();
        if(block.timestamp < tgeTriggeredAt + presaleInfo.cliff) revert cliff_period_not_ended();
        Participant memory participant = participantDetails[_participant];
        if(participant.totalGMG <= participant.withdrawnGMG) revert everything_has_claimed();
        uint256 totalVestingAmount = (participant.totalGMG * ((100 - presaleInfo.tgePercentage) * BPS)) / (100 * BPS);

        uint256 claimableMonths = participant.lastVestedClaimedAt == 0 ? 
                                  (block.timestamp - tgeTriggeredAt) / 30 days :
                                  (block.timestamp - participant.lastVestedClaimedAt) / 30 days;

        if(claimableMonths == 0) revert nothing_to_claim();
        uint256 monthlyClaimable = totalVestingAmount / presaleInfo.vestingMonths;
        uint256 claimableAmount = participant.claimableVestedGMG < monthlyClaimable ? 
                                  participant.claimableVestedGMG : monthlyClaimable;

        participant.claimableVestedGMG -= claimableAmount;
        participant.withdrawnGMG += claimableAmount;
        _gmg.transfer(_participant, claimableAmount);

        emit VestingTokensClaimed(_participant, 1, msg.sender == owner(), 0);
    }

    //@audit Why not invoke the buyWithBnb logic inside this?
    receive() external payable{}
}