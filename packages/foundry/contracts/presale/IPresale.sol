// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPresale {
   
   /*
   --------------------------
   ----------STRUCTS----------
   --------------------------
   */
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
        uint256 releaseOnTGE;
        uint256 vestedAmount;
        uint256 totalBoughtInUsd;
        bool isParticipant;
    }
    
   /*
   --------------------------
   ----------ERRORS----------
   --------------------------
   */

   error PSNA(); // PSNA - presale stage not active
   error LE(); // LE - limit exceeded
   error null_address();
   error insufficient_tokens();
   error only_participant_or_owner();
   error tge_triggered();
   error tge_not_triggered();
   error cliff_period_not_ended();


   /*
   --------------------------
   ----------EVENTS----------
   --------------------------
   */

   event PresaleContractCreated(address indexed contractAddress, address indexed owner);
   event PresaleStarted(uint256 indexed presaleStartTime, bool indexed isPresaleActive);
   event BoughtWithBnb(address indexed buyer, uint256 amountInBnb, uint256 gmgTokens);
   event BoughtWithUsdt(address indexed buyer, uint256 amountInUsdt, uint256 gmgTokens);
   event TgeTriggered(uint256 triggeredAt, bool isTriggered);
   event TgeClaimed(address indexed claimedTo, uint256 amountClaimed, bool claimedByOwner);
}
