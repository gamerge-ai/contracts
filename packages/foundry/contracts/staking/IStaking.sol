// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStaking {
    
    enum StakingPeriod {
        THREE_MONTHS,    // 3 months, 3% APY, 0.25% per month
        SIX_MONTHS,      // 6 months, 4% APY, 0.33% per month  
        NINE_MONTHS,     // 9 months, 5% APY, 0.41% per month
        TWELVE_MONTHS    // 12 months, 6% APY, 0.50% per month
    }

    struct StakeInfo {
        uint256 amount;           // Amount of GMG tokens staked
        uint256 stakedAt;         // Timestamp when staked
        uint256 maturityTime;     // Timestamp when stake matures
        StakingPeriod period;     // Staking period chosen
        uint256 withdrawnRewards; // Total rewards withdrawn so far
        bool isActive;            // Whether stake is still active
    }

    struct InitParams {
        address gmgToken;         // GMG token contract address
        address owner;            // Owner of the staking contract
    }

    /*
    --------------------------
    ----------ERRORS----------
    --------------------------
    */
    
    error InvalidAmount();
    error InvalidStakingPeriod();
    error StakeNotFound();
    error StakeAlreadyWithdrawn();
    error StakeNotMatured();
    error CanOnlyUnstakeWithPenalty();
    error InsufficientRewardsBalance();
    error InsufficientContractBalance();
    error TransferFailed();
    error NotStakeOwner();
    error ContractPaused();
    error ZeroAddress();

    /*
    --------------------------
    ----------EVENTS----------
    --------------------------
    */
    
    event Staked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 amount,
        StakingPeriod period,
        uint256 maturityTime,
        uint256 expectedRewards
    );
    
    event Unstaked(
        address indexed user,
        uint256 indexed stakeId,
        uint256 principal,
        uint256 totalWithdrawn,
        bool isEarlyUnstake
    );
    
    event RewardsWithdrawn(
        address indexed user,
        uint256 indexed stakeId,
        uint256 rewardsAmount,
        uint256 totalRewardsWithdrawn
    );
    
    event EmergencyWithdrawal(
        IERC20 indexed token,
        address indexed to,
        uint256 amount
    );

    event StakingContractPaused(bool paused);

    /*
    --------------------------
    ----------FUNCTIONS----------
    --------------------------
    */

    function initialize(InitParams calldata params) external;

    // EXTERNAL STAKING FUNCTIONS
    function stake(uint256 amount, StakingPeriod period) external;
    
    function unstake(uint256 stakeId) external;
    
    function withdraw(uint256 stakeId, uint256 rewardsAmount) external;

    // EXTERNAL RESTRICTED FUNCTIONS  
    function pause() external;
    
    function unpause() external;
    
    function emergencyWithdraw(IERC20 token, address to, uint256 amount) external;

    // VIEW FUNCTIONS
    function getUserStakes(address user) external view returns (StakeInfo[] memory);
    
    function getStakeInfo(address user, uint256 stakeId) external view returns (StakeInfo memory);
    
    function calculateRewards(uint256 amount, StakingPeriod period) external pure returns (uint256);
    
    function calculateRewardsForDuration(uint256 amount, StakingPeriod period, uint256 actualDuration) external pure returns (uint256);
    
    function getAvailableRewards(address user, uint256 stakeId) external view returns (uint256);
    
    function calculateEarlyWithdrawalPenalty(uint256 amount) external pure returns (uint256);
    
    function getStakingPeriodDuration(StakingPeriod period) external pure returns (uint256);
    
    function getUserStakeCount(address user) external view returns (uint256);
    
    function isPaused() external view returns (bool);
    
    function getTotalStaked() external view returns (uint256);
}