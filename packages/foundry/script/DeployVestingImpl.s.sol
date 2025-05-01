// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";
import { Vesting } from "../contracts/presale/Vesting.sol";

contract DeployVestingImpl is Script {
  function run() public {
    vm.startBroadcast( vm.envUint("HOLESKY_PRIVATE_KEY"));
    Vesting vestingImpl = new Vesting();
    vm.stopBroadcast();

    console.log("Vesting Implementation at:", address(vestingImpl));
  }
}
