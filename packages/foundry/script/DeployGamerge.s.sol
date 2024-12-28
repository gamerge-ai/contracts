//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/Gamerge.sol";
import "./DeployHelpers.s.sol";

contract DeployGamergeTokenContract is ScaffoldETHDeploy {
  // use `deployer` from `ScaffoldETHDeploy`
  function run() external ScaffoldEthDeployerRunner {
    Gamerge yourContract = new Gamerge();
    console.logString(
      string.concat(
        "Gamerge Token deployed at: ", vm.toString(address(yourContract))
      )
    );
  }
}
