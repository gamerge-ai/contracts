// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Presale is Ownable {

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
        uint256 totalAllocation;
        uint256 tgeReleased;
        uint256 vestedAmount;
        uint256 lastClaimed;
    }
    /// @notice Details of referral rewards
    struct Referral {
        uint256 totalEarned;
        uint256 tgeClaimed;
        uint256 vestedClaimed;
    }

    /// @notice Mapping to store participant details
    mapping(address => Participant) public participants;
    /// @notice Mapping to store referral details
    mapping(address => Referral) public referrals;

    /// @notice Allocation of tokens for presale
    uint88 public constant PRESALE_SUPPLY = 19_500_000 * 1e18; // 19.5 million tokens
    /// @notice Allocation of tokens for fairsale
    uint88 public constant FAIRSALE_SUPPLY = 2_000_000 * 1e18; // 2 million tokens
    /// @notice Maximum purchase amount per address during presale (in USD)
    uint48 public constant MAX_PURCHASE_LIMIT = 1000 * 1e6;
    /// @notice Referral bonus percentage
    uint8 public constant REFERRAL_BONUS = 10; // 10% referral bonus

    /// @notice Array to store information about all presale stages
    PresaleStage[5] public presaleStages;

    constructor() Ownable(msg.sender) {

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

    }
}