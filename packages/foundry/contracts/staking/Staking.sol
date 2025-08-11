// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IStaking } from "./IStaking.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is
    IStaking,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 private constant PRECISION = 10000;
    uint256 private constant EARLY_WITHDRAWAL_PENALTY = 1000;
    uint256 private constant SECONDS_IN_MONTH = 30 days;
    uint256 private constant THREE_MONTH_APY = 300;
    uint256 private constant SIX_MONTH_APY = 400;
    uint256 private constant NINE_MONTH_APY = 500;
    uint256 private constant TWELVE_MONTH_APY = 600;

    IERC20 public gmgToken;
    
    uint256 public totalStaked;
    
    mapping(address => StakeInfo[]) public userStakes;
    mapping(address => uint256) public userStakeCount;

    modifier validStakeId(address user, uint256 stakeId) {
        if (stakeId >= userStakes[user].length) revert StakeNotFound();
        if (!userStakes[user][stakeId].isActive) revert StakeAlreadyWithdrawn();
        _;
    }

    modifier onlyStakeOwner(address user, uint256 stakeId) {
        if (msg.sender != user) revert NotStakeOwner();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(InitParams calldata params) external override initializer {
        if (params.gmgToken == address(0) || params.owner == address(0)) {
            revert ZeroAddress();
        }

        __Ownable_init(params.owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        gmgToken = IERC20(params.gmgToken);
    }


    /*
    --------------------------
    ----------EXTERNAL STAKING FUNCTIONS----------
    --------------------------
    */

    function stake(
        uint256 amount, 
        StakingPeriod period
    ) external override nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();
        if (uint256(period) > 3) revert InvalidStakingPeriod();

        uint256 duration = getStakingPeriodDuration(period);
        uint256 maturityTime = block.timestamp + duration;

        StakeInfo memory newStake = StakeInfo({
            amount: amount,
            stakedAt: block.timestamp,
            maturityTime: maturityTime,
            period: period,
            withdrawnRewards: 0,
            isActive: true
        });

        userStakes[msg.sender].push(newStake);
        userStakeCount[msg.sender]++;
        totalStaked += amount;

        gmgToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(
            msg.sender,
            userStakes[msg.sender].length - 1,
            amount,
            period,
            maturityTime,
            calculateRewards(amount, period)
        );
    }

    function unstake(
        uint256 stakeId
    ) external override nonReentrant validStakeId(msg.sender, stakeId) onlyStakeOwner(msg.sender, stakeId) {
        StakeInfo storage stakeInfo = userStakes[msg.sender][stakeId];
        
        uint256 principal = stakeInfo.amount;
        uint256 actualDuration = block.timestamp - stakeInfo.stakedAt;
        uint256 plannedDuration = stakeInfo.maturityTime - stakeInfo.stakedAt;
        
        uint256 rewards;
        uint256 penalty = 0;
        uint256 totalWithdrawal;
        bool isEarlyUnstake = false;

        if (actualDuration >= plannedDuration) {
            // Matured stake - calculate full rewards for actual duration
            rewards = calculateRewardsForDuration(principal, stakeInfo.period, actualDuration);
            totalWithdrawal = principal + rewards;
        } else {
            // Early unstake - deduct penalty from principal, no rewards
            isEarlyUnstake = true;
            penalty = calculateEarlyWithdrawalPenalty(principal);
            totalWithdrawal = principal - penalty;
            rewards = 0;
        }

        if (gmgToken.balanceOf(address(this)) < totalWithdrawal) {
            revert InsufficientContractBalance();
        }

        stakeInfo.isActive = false;
        totalStaked -= principal;

        gmgToken.safeTransfer(msg.sender, totalWithdrawal);

        emit Unstaked(msg.sender, stakeId, principal, rewards, penalty, totalWithdrawal, isEarlyUnstake);
    }

    function withdraw(
        uint256 stakeId,
        uint256 rewardsAmount
    ) external override nonReentrant validStakeId(msg.sender, stakeId) onlyStakeOwner(msg.sender, stakeId) {
        StakeInfo storage stakeInfo = userStakes[msg.sender][stakeId];
        
        uint256 actualDuration = block.timestamp - stakeInfo.stakedAt;
        uint256 plannedDuration = stakeInfo.maturityTime - stakeInfo.stakedAt;
        
        if (actualDuration < plannedDuration) {
            revert CanOnlyUnstakeWithPenalty();
        }

        uint256 availableRewards = getAvailableRewards(msg.sender, stakeId);
        
        if (rewardsAmount > availableRewards) {
            revert InsufficientRewardsBalance();
        }

        if (gmgToken.balanceOf(address(this)) < rewardsAmount) {
            revert InsufficientContractBalance();
        }

        stakeInfo.withdrawnRewards += rewardsAmount;

        gmgToken.safeTransfer(msg.sender, rewardsAmount);

        emit RewardsWithdrawn(msg.sender, stakeId, rewardsAmount, stakeInfo.withdrawnRewards);
    }


    /*
    --------------------------
    ----------EXTERNAL RESTRICTED FUNCTIONS----------
    --------------------------
    */

    function pause() external override onlyOwner {
        _pause();
        emit ContractPaused(true);
    }

    function unpause() external override onlyOwner {
        _unpause();
        emit ContractPaused(false);
    }

    function emergencyWithdraw(
        IERC20 token,
        address to,
        uint256 amount
    ) external override onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        
        token.safeTransfer(to, amount);
        
        emit EmergencyWithdrawal(token, to, amount);
    }


    /*
    --------------------------
    ----------VIEW FUNCTIONS----------
    --------------------------
    */

    function getUserStakes(address user) external view override returns (StakeInfo[] memory) {
        return userStakes[user];
    }

    function getStakeInfo(
        address user,
        uint256 stakeId
    ) external view override returns (StakeInfo memory) {
        if (stakeId >= userStakes[user].length) revert StakeNotFound();
        return userStakes[user][stakeId];
    }

    function calculateRewards(
        uint256 amount,
        StakingPeriod period
    ) public pure override returns (uint256) {
        uint256 apy;
        uint256 months;

        if (period == StakingPeriod.THREE_MONTHS) {
            apy = THREE_MONTH_APY;
            months = 3;
        } else if (period == StakingPeriod.SIX_MONTHS) {
            apy = SIX_MONTH_APY;
            months = 6;
        } else if (period == StakingPeriod.NINE_MONTHS) {
            apy = NINE_MONTH_APY;
            months = 9;
        } else if (period == StakingPeriod.TWELVE_MONTHS) {
            apy = TWELVE_MONTH_APY;
            months = 12;
        } else {
            revert InvalidStakingPeriod();
        }

        return (amount * apy * months) / (PRECISION * 12);
    }

    function calculateEarlyWithdrawalPenalty(
        uint256 amount
    ) public pure override returns (uint256) {
        return (amount * EARLY_WITHDRAWAL_PENALTY) / PRECISION;
    }

    function calculateRewardsForDuration(
        uint256 amount,
        StakingPeriod period,
        uint256 actualDuration
    ) public pure override returns (uint256) {
        uint256 apy;

        if (period == StakingPeriod.THREE_MONTHS) {
            apy = THREE_MONTH_APY;
        } else if (period == StakingPeriod.SIX_MONTHS) {
            apy = SIX_MONTH_APY;
        } else if (period == StakingPeriod.NINE_MONTHS) {
            apy = NINE_MONTH_APY;
        } else if (period == StakingPeriod.TWELVE_MONTHS) {
            apy = TWELVE_MONTH_APY;
        } else {
            revert InvalidStakingPeriod();
        }

        // Convert actual duration from seconds to years for APY calculation
        // actualDuration / (365 days)
        return (amount * apy * actualDuration) / (PRECISION * 365 days);
    }

    function getAvailableRewards(
        address user,
        uint256 stakeId
    ) public view override returns (uint256) {
        if (stakeId >= userStakes[user].length) revert StakeNotFound();
        if (!userStakes[user][stakeId].isActive) return 0;
        
        StakeInfo storage stakeInfo = userStakes[user][stakeId];
        uint256 actualDuration = block.timestamp - stakeInfo.stakedAt;
        
        uint256 totalRewards = calculateRewardsForDuration(stakeInfo.amount, stakeInfo.period, actualDuration);
        return totalRewards - stakeInfo.withdrawnRewards;
    }

    function getStakingPeriodDuration(
        StakingPeriod period
    ) public pure override returns (uint256) {
        if (period == StakingPeriod.THREE_MONTHS) {
            return 3 * SECONDS_IN_MONTH;
        } else if (period == StakingPeriod.SIX_MONTHS) {
            return 6 * SECONDS_IN_MONTH;
        } else if (period == StakingPeriod.NINE_MONTHS) {
            return 9 * SECONDS_IN_MONTH;
        } else if (period == StakingPeriod.TWELVE_MONTHS) {
            return 12 * SECONDS_IN_MONTH;
        } else {
            revert InvalidStakingPeriod();
        }
    }

    function getUserStakeCount(address user) external view override returns (uint256) {
        return userStakeCount[user];
    }

    function isPaused() external view override returns (bool) {
        return paused();
    }

    function getTotalStaked() external view override returns (uint256) {
        return totalStaked;
    }


    /*
    --------------------------
    ----------UPGRADE RESTRICTION----------
    --------------------------
    */

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}