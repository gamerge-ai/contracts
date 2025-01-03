//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../contracts/presale/interfaces/IPresale.sol";
import "../contracts/Gamerge.sol";
import "../contracts/presale/PresaleFactory.sol";
import "../contracts/presale/Presale.sol";
import "../contracts/presale/Vesting.sol";
// import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "./DeployHelpers.s.sol";

contract DeployGamergeTokenContract is ScaffoldETHDeploy {
  // use `deployer` from `ScaffoldETHDeploy`
  function run() external ScaffoldEthDeployerRunner {
    console.logString(string.concat("Deploying Gamerge Token Contract on: "));
    Gamerge yourContract = new Gamerge();

    console.logString(
      string.concat(
        "Gamerge Token deployed at: ", vm.toString(address(yourContract))
      )
    );
    Presale presale = new Presale();
    console.logString(
      string.concat("Presale deployed at: ", vm.toString(address(presale)))
    );
    Vesting vesting = new Vesting();
    console.logString(
      string.concat("Vesting deployed at: ", vm.toString(address(vesting)))
    );
    PresaleFactory presaleFactory = new PresaleFactory(
      presale,
      vesting,
      address(0x694AA1769357215DE4FAC081bf1f309aDC325306),
      address(yourContract),
      address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)
    );
    console.logString(
      string.concat(
        "Presale Factory deployed at: ", vm.toString(address(presaleFactory))
      )
    );
  }
}
