// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPresale} from "./helperLibraries/IPresale.sol";
// import {SafeMath} from "./helperLibraries/safeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Presale is Ownable, ReentrancyGuard, IPresale {

    /// @notice Mapping to store participant details
    mapping(address => Participant) public participantDetails;
    /// @notice Mapping to store referral details
    mapping(address => uint256) public individualReferralAmount;

    /// @notice Allocation of tokens for presale
    uint88 public constant PRESALE_SUPPLY = 19_500_000 * 1e18; // 19.5 million tokens
    /// @notice Allocation of tokens for fairsale
    uint88 public constant FAIRSALE_SUPPLY = 2_000_000 * 1e18; // 2 million tokens
    /// @notice Maximum purchase amount per address during presale (in USD)
    uint48 public constant MAX_PURCHASE_LIMIT = 1000 * 1e6;
    /// @notice Referral bonus percentage
    uint8 public constant REFERRAL_BONUS = 10; // 10% referral bonus
    /// @notice Index of the current presale stage
    uint8 public currentStageIndex;
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
    Participant[] public participants;
    /// @notice Initializes the Chainlink or Oracle price aggregator interface for ETH prices.
    AggregatorV3Interface public immutable bnbPriceAggregator;

    /// @notice Initializing SafeMath for arithmetic operations
    // using SafeMath for *;

    /// @notice Immutable reference to the GMG ERC20 token 
    IERC20 private immutable _gmg;
    /// @notice Immutable reference to the USDT ERC20 token
    IERC20 private immutable _usdt;

    /// @notice Private function to check if the presale stage is active.
    /// @dev Reverts with a custom error PSNA (Presale Stage Not Active) if the presale is inactive.
    function _isPresaleActive() view private{
        if(!isActive) revert PSNA(); // PSNA - presale stage not active
    }

    // @notice Modifier to check whether presale stage is active before executing a function or not.
    /// @dev Calls the private function `_isPresaleActive` to perform the check.
    modifier isPresaleActive() {
        _isPresaleActive();
        _;
    }

    function _limitExceeded(address user, uint256 amount) view private {
        if(participantDetails[user].totalBoughtInUsd + amount > MAX_PURCHASE_LIMIT) revert LE();
    }


    constructor(
        uint16 _tokenPrice,
        uint88 _tokenAllocation,
        uint24 _cliff,
        uint8 _vestingMonths,
        uint8 _tgePercentages,
        address _bnbPriceAggregator, 
        address _gmgAddress, 
        address _usdtAddress
        ) Ownable(msg.sender) {

        // uint16[5] memory prices = [0.01 * 1e6, 0.02 * 1e6, 0.03 * 1e6, 0.04 * 1e6, 0.05 * 1e6];
        // uint88[5] memory allocations = [1_000_000 * 1e18, 1_500_000  * 1e18, 2_000_000  * 1e18, 5_000_000  * 1e18, 10_000_000  * 1e18];
        // uint24[5] memory cliffs = [30 days, 45 days, 60 days, 75 days, 90 days];
        // uint8[5] memory vestingMonths = [36, 30, 24, 18, 12];
        // uint8[5] memory tgePercentages = [20, 15, 10, 5, 0];

        // for (uint256 i = 0; i < presaleStages.length; i++) {
        //     presaleStages[i] = PresaleStage(
        //         prices[i],
        //         allocations[i],
        //         cliffs[i],
        //         vestingMonths[i],
        //         tgePercentages[i]
        //     );
        // }

        presaleStage = PresaleStage(_tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages);
        bnbPriceAggregator = AggregatorV3Interface(_bnbPriceAggregator);
        _gmg = IERC20(_gmgAddress);
        _usdt = IERC20(_usdtAddress);
        emit PresaleContractCreated(address(this), owner());
    }

    function startPresale() public onlyOwner returns(uint256, bool) {
        presaleStartTime = block.timestamp;
        bool tokenSuccess = _gmg.transferFrom(msg.sender, address(this), presaleStage.allocation);
        require(tokenSuccess, "GMG transfer failed to contract");
        isActive = true;
        emit PresaleStarted(presaleStartTime, isActive);
        return (presaleStartTime, isActive);
    }

    function buyWithBnb(address referral) public isPresaleActive nonReentrant payable {
        uint256 decimals = bnbPriceAggregator.decimals() - 6;
        (, int256 latestPrice , , ,)  = bnbPriceAggregator.latestRoundData();
        uint256 bnbInUsd = uint(latestPrice)/(10 ** decimals);
        uint256 valueInUsd = bnbInUsd * (msg.value);
        _limitExceeded(msg.sender, valueInUsd);
        uint256 gmgTokens = valueInUsd/(presaleStage.pricePerToken);

        uint256 amountToReferral;
        uint256 amountToContract;
        if(referral == address(0)) {
            amountToContract = msg.value;
        } else {
            amountToReferral = (msg.value * 10)/(100);
            amountToContract = msg.value - amountToReferral;
            individualReferralAmount[referral] += amountToReferral;
            (bool success, ) = referral.call{value: amountToReferral}("");
            require(success, "BNB transfer failed to Referral");
        }

        if(!participantDetails[msg.sender].isParticipant) {
            participantDetails[msg.sender].isParticipant = true;
        }
        participantDetails[msg.sender].totalGMG += gmgTokens;
        participantDetails[msg.sender].totalBoughtInUsd += valueInUsd;
        participantDetails[msg.sender].releaseOnTGE += (gmgTokens * 20) / 100; 
        totalBnb += amountToContract;

        _gmg.transfer(msg.sender, gmgTokens);

        emit BoughtWithBnb(msg.sender, msg.value, gmgTokens);
    }

    function buyWithUsdt(uint256 usdtAmount, address referral) public isPresaleActive nonReentrant {
        uint256 gmgTokens = usdtAmount / (presaleStage.pricePerToken);
        if(gmgTokens < _gmg.balanceOf(address(this))) revert insufficient_tokens();
        bool success = _usdt.transferFrom(msg.sender, address(this), usdtAmount);
        require(success, "USDT transfer failed to Contract");
        _limitExceeded(msg.sender, usdtAmount);

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

        if(!participantDetails[msg.sender].isParticipant) {
            participantDetails[msg.sender].isParticipant = true;
        }
        participantDetails[msg.sender].totalGMG += gmgTokens;
        participantDetails[msg.sender].totalBoughtInUsd += usdtAmount;
        participantDetails[msg.sender].releaseOnTGE += (gmgTokens * 20) / 100; 
        totalUsdt += amountToContract;

        _gmg.transfer(msg.sender, gmgTokens);

        emit BoughtWithUsdt(msg.sender, usdtAmount, gmgTokens);
    }

    function triggerTGE() public onlyOwner nonReentrant {
        // if(presaleStartTime.add(presaleStage.cliff) < block.timestamp) revert (""); // i am not sure when to trigger this
        if(isTgeTriggered) revert tge_triggered();
        tgeTriggeredAt = block.timestamp;
        isTgeTriggered = true;
        emit TgeTriggered(tgeTriggeredAt, isTgeTriggered);
    }

    function claimTGE(address _participant) public nonReentrant {
        if(msg.sender == _participant || msg.sender == owner()) revert only_participant_or_owner();
        if(!isTgeTriggered) revert tge_not_triggered();
        uint256 claimableGMG = participantDetails[_participant].releaseOnTGE;
        participantDetails[_participant].releaseOnTGE = 0;
        participantDetails[_participant].withdrawnGMG += claimableGMG;
        _gmg.transfer(_participant, claimableGMG);
        emit TgeClaimed(_participant, claimableGMG, msg.sender == owner());
    }

    function claimVestingAmount(address _participant) public nonReentrant {
        if(msg.sender == _participant || msg.sender == owner()) revert only_participant_or_owner();
        if(block.timestamp < tgeTriggeredAt + presaleStage.cliff) revert cliff_period_not_ended();
        
    }

    receive() external payable{}
}