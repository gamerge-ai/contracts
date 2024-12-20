// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/interfaces/feeds/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ErrorAndEventsLibrary} from "./helperLibraries/errorEventsLibrary.sol";
import {SafeMath} from "./helperLibraries/safeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Presale is Ownable, ReentrancyGuard {

    /// @notice Details of single presale stage
    struct PresaleStage {
        uint16 pricePerToken;
        uint88 allocation;
        uint24 cliff;
        uint8 vestingMonths;
        uint8 tgePercentage;
    }
    /// @notice Details of user purchase and vesting progress
    struct Participant {
        uint256 totalGMG;
        uint256 withdrawnGMG;
        mapping(uint256 => uint256) releaseOnTGE;
        uint256 vestedAmount;
        uint256 totalBoughtInUsd;
    }

    /// @notice Mapping to store participant details
    mapping(address => Participant) public participants;
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

    bool public isActive = false; 

    /// @notice Array to store information about all presale stages
    PresaleStage[5] public presaleStages;
    /// @notice Initializes the Chainlink or Oracle price aggregator interface for ETH prices.
    AggregatorV3Interface public immutable bnbPriceAggregator;

    /// @notice Initializing ErrorAndEventsLibrary for custom errors and events
    using ErrorAndEventsLibrary for *;
    //@audit Why used safeMath?
    /// @notice Initializing SafeMath for arithmetic operations
    using SafeMath for *;

    /// @notice Immutable reference to the GMG ERC20 token 
    IERC20 private immutable _gmg;
    /// @notice Immutable reference to the USDT ERC20 token
    IERC20 private immutable _usdt;

    /// @notice Private function to check if the presale stage is active.
    /// @dev Reverts with a custom error PSNA (Presale Stage Not Active) if the presale is inactive.
    function _isPresaleActive() view private{
        if(!isActive) revert ErrorAndEventsLibrary.PSNA(); // PSNA - presale stage not active
    }

    // @notice Modifier to check whether presale stage is active before executing a function or not.
    /// @dev Calls the private function `_isPresaleActive` to perform the check.
    modifier isPresaleActive() {
        _isPresaleActive();
        _;
    }

    function _limitExceeded(address user, uint256 amount) view private {
        //@audit `1000` must be replaced with MAX_PURCHASE_LIMIT
        if(participants[user].totalBoughtInUsd + amount > 1000) revert ErrorAndEventsLibrary.LE();
    }

    constructor(address _bnbPriceAggregator, address _gmgAddress, address _usdtAddress) Ownable(msg.sender) {

        uint16[5] memory prices = [0.01 * 1e6, 0.02 * 1e6, 0.03 * 1e6, 0.04 * 1e6, 0.05 * 1e6];
        uint88[5] memory allocations = [1_000_000 * 1e18, 1_500_000  * 1e18, 2_000_000  * 1e18, 5_000_000  * 1e18, 10_000_000  * 1e18];
        uint24[5] memory cliffs = [30 days, 45 days, 60 days, 75 days, 90 days];
        uint8[5] memory vestingMonths = [36, 30, 24, 18, 12];
        uint8[5] memory tgePercentages = [20, 15, 10, 5, 0];

        for (uint256 i = 0; i < presaleStages.length; i++) {
            presaleStages[i] = PresaleStage(
                prices[i],
                allocations[i],
                cliffs[i],
                vestingMonths[i],
                tgePercentages[i]
            );
        }

        bnbPriceAggregator = AggregatorV3Interface(_bnbPriceAggregator);
        _gmg = IERC20(_gmgAddress);
        _usdt = IERC20(_usdtAddress);
        emit ErrorAndEventsLibrary.PresaleContractCreated(address(this), owner());
    }

    function startPresale() public onlyOwner returns(uint256, bool) {
        presaleStartTime = block.timestamp;
        isActive = true;
        emit ErrorAndEventsLibrary.PresaleStarted(presaleStartTime, isActive);
        return (presaleStartTime, isActive);
    }

    //@audit use BPS for percentage calculations
    function buyWithBnb(uint8 _presaleStage, address referral) public isPresaleActive nonReentrant payable {
        uint256 decimals = bnbPriceAggregator.decimals().sub(6);
        (, int256 latestPrice , , ,)  = bnbPriceAggregator.latestRoundData();
        uint256 bnbInUsd = uint(latestPrice).div(10 ** decimals);
        uint256 valueInUsd = bnbInUsd.mul(msg.value);
        _limitExceeded(msg.sender, valueInUsd);
        uint256 gmgTokens = valueInUsd.div(presaleStages[_presaleStage].pricePerToken);

        uint256 amountToReferral;
        uint256 amountToContract;
        if(referral == address(0)) {
            amountToContract = msg.value;
        } else {
            amountToReferral = (msg.value.mul(10)).div(100);
            amountToContract = msg.value.sub(amountToReferral);
            individualReferralAmount[referral] = individualReferralAmount[referral].add(amountToReferral);
            (bool success, ) = referral.call{value: amountToReferral}("");
            require(success, "BNB transfer failed to Referral");
        }

        participants[msg.sender].totalGMG = participants[msg.sender].totalGMG.add(gmgTokens);
        participants[msg.sender].totalBoughtInUsd = participants[msg.sender].totalBoughtInUsd.add(valueInUsd);
        totalBnb = totalBnb.add(amountToContract);

        _gmg.transfer(msg.sender, gmgTokens);

        emit ErrorAndEventsLibrary.BoughtWithBnb(msg.sender, msg.value, gmgTokens);
    }

    function buyWithUsdt(uint8 _presaleStage, uint256 usdtAmount, address referral) public isPresaleActive nonReentrant {
        
        bool success = _usdt.transferFrom(msg.sender, address(this), usdtAmount);
        require(success, "USDT transfer failed to Contract");
        _limitExceeded(msg.sender, usdtAmount);
        uint256 gmgTokens = usdtAmount.div(presaleStages[_presaleStage].pricePerToken);

        uint256 amountToReferral;
        uint256 amountToContract;
        if(referral == address(0)) {
            amountToContract = usdtAmount;
        } else {
            amountToReferral = (usdtAmount.mul(10)).div(100);
            amountToContract = usdtAmount.sub(amountToReferral);
            individualReferralAmount[referral] = individualReferralAmount[referral].add(amountToReferral);
            bool referralSuccess = _usdt.transfer(referral, amountToReferral);
            require(referralSuccess, "USDT transfer failed to Referral");
        }

        participants[msg.sender].totalGMG = participants[msg.sender].totalGMG.add(gmgTokens);
        participants[msg.sender].totalBoughtInUsd = participants[msg.sender].totalBoughtInUsd.add(usdtAmount);
        totalUsdt = totalUsdt.add(amountToContract);

        _gmg.transfer(msg.sender, gmgTokens);

        emit ErrorAndEventsLibrary.BoughtWithUsdt(msg.sender, usdtAmount, gmgTokens);
    }

    function triggerTGE(uint8 _presaleStage) public onlyOwner nonReentrant {
        if(presaleStartTime.add(presaleStages[_presaleStage].cliff) < block.timestamp) revert ("");

    }


    // function getCurrentStage() public view returns(uint256) {
    //     uint256 elapsedTime = block.timestamp - presaleStartTime;
    //     uint256 cumulativeTime = 0;

    //     for (uint256 i = 0; i < presaleStages.length; i++) {
    //         cumulativeTime += presaleStages[i].cliff;
    //         if (elapsedTime < cumulativeTime) {
    //             return i;
    //         }
    //     }
    // }

    receive() external payable{}
}