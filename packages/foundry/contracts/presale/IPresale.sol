// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPresale {
   enum ASSET{BNB, USDT}

   /*
   --------------------------
   ----------STRUCTS----------
   --------------------------
   */
   /// @notice Details of single presale stage
   struct PresaleInfo {
        uint16 pricePerToken;
        uint88 allocation;
        uint24 cliff;
        uint8 vestingMonths;
        uint8 tgePercentage;
        uint8 presaleStage;
    }
    /// @notice Details of user purchase and vesting progress
    struct Participant {
        uint256 totalGMG; // Total GMG bought
        uint256 withdrawnGMG; // GMG amount withdraw so far, includes both TGE and Vesting
        uint256 releaseOnTGE; // GMG amount to be released after TGE
        uint256 claimableVestedGMG; // GMG amount that will be released during vesting period
        uint256 lastVestedClaimedAt;
        bool isParticipant;
    }
    
   /*
   --------------------------
   ----------ERRORS----------
   --------------------------
   */

   error max_limit_exceeded();
   error null_address();
   error insufficient_tokens();
   error only_participant_or_owner();
   error tge_already_triggered();
   error tge_not_triggered();
   error cliff_period_not_ended();
   error not_a_participant();
   error nothing_to_claim();
   error everything_has_claimed();
   error referral_withdrawal_failed();
   error cannot_claim_zero_amount();
   error total_gmg_sold_out(uint256 gmgLeft);


   /*
   --------------------------
   ----------EVENTS----------
   --------------------------
   */

   event PresaleStarted(uint8 indexed presaleStage);
   event BoughtWithBnb(address indexed buyer, uint256 amountInBnb, uint256 gmgTokens);
   event BoughtWithUsdt(address indexed buyer, uint256 amountInUsdt, uint256 gmgTokens);
   event TgeTriggered(uint256 triggeredAt, bool isTriggered);
   event TgeClaimed(address indexed claimedTo, uint256 amountClaimed, bool claimedByOwner);
   event VestingTokensClaimed(address indexed withdrawnTo, uint256 amountWithdrawn, bool withdrawnByOwner, uint256 remainingAmount);

    /*
   --------------------------
   ----------FUNCTIONS----------
   --------------------------
   */

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
        ) external;
}
