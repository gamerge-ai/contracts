// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { Vesting } from "../contracts/presale/Vesting.sol";

contract DeployVestingImpl is Script {
  function run() public {
    Vesting vestingImpl = new Vesting();

    console2.log("Vesting Implementation at:", address(vestingImpl));
  }
}
