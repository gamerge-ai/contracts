// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ErrorAndEventsLibrary {
    
   /*
   --------------------------
   ----------ERRORS----------
   --------------------------
   */

   error PSNA(); // PSNA - presale stage not active
   error LE(); // LE - limit exceeded


   /*
   --------------------------
   ----------EVENTS----------
   --------------------------
   */

   event PresaleContractCreated(address indexed contractAddress, address indexed owner);
   event PresaleStarted(uint256 indexed presaleStartTime, bool indexed isPresaleActive);
   event BoughtWithBnb(address indexed buyer, uint256 amountInBnb, uint256 gmgTokens);
}
