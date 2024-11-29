//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contracts/Gamerge.sol";

contract DeployScript is Script {
  function run() external returns(Gamerge gamerge) {
    gamerge = new Gamerge();
  }
}
