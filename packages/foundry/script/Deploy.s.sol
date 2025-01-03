//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { DeployGamergeTokenContract } from "./DeployGamerge.s.sol";

contract DeployScript is ScaffoldETHDeploy {
  function run() external {
    DeployGamergeTokenContract deployYourContract =
      new DeployGamergeTokenContract();
    deployYourContract.run();

    // deploy more contracts here
    // DeployMyContract deployMyContract = new DeployMyContract();
    // deployMyContract.run();
  }
}
