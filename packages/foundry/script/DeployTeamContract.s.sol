// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import {TeamContract} from "../contracts/team/Team.sol";

import { console2 } from "forge-std/console2.sol";

contract DeployTeamContract is Script {

    function run() external {
        uint256 deployerKey = vm.envUint("NITHIN_TEST_PRIVATE_KEY");

        address gmgToken = 0x10247f7A10aAF32D94691F6FbE51d8aC434a0d8E;
        address owner = 0x8356D265646a397b2Dacf0e05A4973E7676597f4;

        vm.startBroadcast(deployerKey);

        TeamContract teamContract = new TeamContract(gmgToken, owner);

        vm.stopBroadcast();

        console2.log("deployed team contract address:", address(teamContract));
    } 
}