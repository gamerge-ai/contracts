// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AggregatorV3Interface} from "@chainlink/brownie/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPresale} from "./IPresale.sol";
import {PresaleFactory} from "./PresaleFactory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Presale is Ownable2Step, ReentrancyGuard, IPresale {

    /// @notice Mapping to store participant details
    mapping(address => Participant) public participantDetails;
    /// @notice Mapping to store referral details
    mapping(address => uint256) public individualReferralAmount;

    /// @notice Maximum purchase amount per address during presale (in USD)
    uint48 public constant MAX_PURCHASE_LIMIT = 1000 * 1e6;
    /// @notice Referral bonus percentage
    uint8 public constant REFERRAL_BONUS = 10; // 10% referral bonus
    /// @notice bps for accurate decimals
    uint16 private constant BPS = 100; // 1% = 100 points
    /// @notice Start time of the presale
    uint256 public presaleStartTime;
    /// @notice total bnb
    uint256 public totalBnb;
    /// @notice total usdt
    uint256 public totalUsdt;
    /// @notice tge triggered time;
    uint256 public tgeTriggeredAt;

    bool public isActive = false; 
    bool public isTgeTriggered = false;

    /// @notice Array to store information about all presale stages
    PresaleStage public presaleStage;
    /// @notice Initializes the Chainlink or Oracle price aggregator interface for ETH prices.
    AggregatorV3Interface public immutable bnbPriceAggregator;

    /// @notice Immutable reference to the GMG ERC20 token 
    IERC20 private immutable _gmg;
    /// @notice Immutable reference to the USDT ERC20 token
    IERC20 private immutable _usdt;

    ///@notice creating instance of the registry contract
    PresaleFactory private gmgRegistry;

    /*
    --------------------------
    ---------MODIFIERS--------
    --------------------------
    */

    /// @notice Modifier to check whether presale stage is active before executing a function or not.
    /// @dev Calls the private function `_isPresaleActive` to perform the check.
    modifier isPresaleActive() {
        _isPresaleActive();
        _;
    }

    modifier onlyOwnerOrParticipant(address _participant) {
        _onlyParticipantOrOwner(_participant);
        _;
    }

    /*
   --------------------------
   --------CONSTRUCTOR-------
   --------------------------
   */
    constructor(
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
        ) Ownable(_owner) {

        gmgRegistry = PresaleFactory(_gmgRegistryAddress);
        presaleStage = PresaleStage(_tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages);
        bnbPriceAggregator = AggregatorV3Interface(_bnbPriceAggregator);
        _gmg = IERC20(_gmgAddress);
        _usdt = IERC20(_usdtAddress);
        // presaleStartTime = block.timestamp;
        // bool tokenSuccess = _gmg.transferFrom(msg.sender, address(this), presaleStage.allocation);
        // require(tokenSuccess, "GMG transfer failed to contract");
        // isActive = true;
        emit PresaleContractCreated(address(this), owner());
    }

    /*
    --------------------------
    ----PRIVATE FUNCTIONS-----
    --------------------------
    */

    /// @notice Private function to check if the presale stage is active.
    /// @dev Reverts with a custom error PSNA (Presale Stage Not Active) if the presale is inactive.
    function _isPresaleActive() view private{
        if(!isActive) revert presale_not_active(); // PSNA - presale stage not active
    }

    function _limitExceeded(address user, uint256 amount) view private {
        if(gmgRegistry.getTotalBought(user) + amount > MAX_PURCHASE_LIMIT) revert max_limit_exceeded();
    }

    function _onlyParticipantOrOwner(address _participant) view private {
        if(msg.sender == _participant || msg.sender == owner()) revert only_participant_or_owner();
    }

    function _buyLogic(address _participant, uint256 valueInUsd, uint256 gmgTokens) private {
        Participant storage participant = participantDetails[_participant];
        if(!participant.isParticipant) {
            participant.isParticipant = true;
        }
        gmgRegistry.updateTotalBought(_participant, valueInUsd);
        participant.totalGMG += gmgTokens;
        uint256 releaseOnTGE = (gmgTokens * (presaleStage.tgePercentage * BPS)) / (100 * BPS);
        participant.claimableVestedGMG += (gmgTokens - releaseOnTGE);
        participant.releaseOnTGE += releaseOnTGE;
    }

    function _buyWithBnb(address participant, address referral, uint256 bnbAmount) private {
        uint256 decimals = bnbPriceAggregator.decimals() - 6;
        (, int256 latestPrice, , ,) = bnbPriceAggregator.latestRoundData();
        uint256 bnbInUsd = uint(latestPrice) / (10 ** decimals);
        uint256 valueInUsd = (bnbInUsd * bnbAmount) / 1e18;

        _limitExceeded(participant, valueInUsd);

        uint256 gmgTokens = (valueInUsd * 1e18) / (presaleStage.pricePerToken * 1e6);
        if (gmgTokens > _gmg.balanceOf(address(this))) revert insufficient_tokens();

        uint256 amountToReferral;
        uint256 amountToContract;
        if (referral == address(0)) {
            amountToContract = bnbAmount;
        } else {
            amountToReferral = (bnbAmount * (10 * BPS)) / (100 * BPS);
            amountToContract = bnbAmount - amountToReferral;
            individualReferralAmount[referral] += amountToReferral;
            (bool success, ) = referral.call{value: amountToReferral}("");
            require(success, "BNB transfer failed to Referral");
        }

        totalBnb += amountToContract;
        _buyLogic(participant, valueInUsd, gmgTokens);

        emit BoughtWithBnb(participant, bnbAmount, gmgTokens);
    }

    /*
    --------------------------
    -----PUBLIC FUNCTIONS-----
    --------------------------
    */

    function startPresale() public onlyOwner returns(uint256, bool) {
        presaleStartTime = block.timestamp;
        bool tokenSuccess = _gmg.transferFrom(msg.sender, address(this), presaleStage.allocation);
        require(tokenSuccess, "GMG transfer failed to contract");
        isActive = true;
        emit PresaleStarted(presaleStartTime, isActive);
        return (presaleStartTime, isActive);
    }

    function buyWithBnb(address referral) public isPresaleActive nonReentrant payable {
        _buyWithBnb(msg.sender, referral, msg.value);
    }


    function buyWithUsdt(uint256 usdtAmount, address referral) public isPresaleActive nonReentrant {
        address participant = msg.sender;
        _limitExceeded(participant, usdtAmount);
        uint256 gmgTokens = (usdtAmount * 1e18) / (presaleStage.pricePerToken * 1e6);
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

    function triggerTGE() public onlyOwner nonReentrant isPresaleActive{
        if(isTgeTriggered) revert tge_already_triggered();
        tgeTriggeredAt = block.timestamp;
        isTgeTriggered = true;
        emit TgeTriggered(tgeTriggeredAt, isTgeTriggered);
    }

    function claimTGE(address _participant) public nonReentrant onlyOwnerOrParticipant(_participant) isPresaleActive {
        Participant memory participant = participantDetails[_participant];
        if(!participant.isParticipant) revert not_a_participant();
        if(!isTgeTriggered) revert tge_not_triggered();
        uint256 claimableGMG = participantDetails[_participant].releaseOnTGE;
        participant.releaseOnTGE = 0;
        participant.withdrawnGMG += claimableGMG;
        _gmg.transfer(_participant, claimableGMG);
        emit TgeClaimed(_participant, claimableGMG, msg.sender == owner());
    }

    function claimVestingAmount(address _participant) public nonReentrant onlyOwnerOrParticipant(_participant) isPresaleActive{
        if(block.timestamp < tgeTriggeredAt + presaleStage.cliff) revert cliff_period_not_ended();
        Participant memory participant = participantDetails[_participant];
        if(participant.totalGMG <= participant.withdrawnGMG) revert everything_has_claimed();
        uint256 totalVestingAmount = (participant.totalGMG * ((100 - presaleStage.tgePercentage) * BPS)) / (100 * BPS);

        uint256 claimableMonths = participant.lastVestedClaimedAt == 0 ? 
                                  (block.timestamp - tgeTriggeredAt) / 30 days :
                                  (block.timestamp - participant.lastVestedClaimedAt) / 30 days;

        if(claimableMonths == 0) revert nothing_to_claim();
        uint256 monthlyClaimable = totalVestingAmount / presaleStage.vestingMonths;
        uint256 claimableAmount = participant.claimableVestedGMG < monthlyClaimable ? 
                                  participant.claimableVestedGMG : monthlyClaimable;

        participant.claimableVestedGMG -= claimableAmount;
        participant.withdrawnGMG += claimableAmount;
        _gmg.transfer(_participant, claimableAmount);

        emit VestingTokensClaimed(_participant, 1, msg.sender == owner(), 0);
    }

    function getIndividualBoughtAmount(address _participant) public view returns(uint256) {
        return gmgRegistry.getTotalBought(_participant);
    }

/// @notice payable receive function to receive native currency
    receive() external payable{
        _buyWithBnb(msg.sender, address(0), msg.value);
    }
}