// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { Staking } from "../contracts/staking/Staking.sol";
import { IStaking } from "../contracts/staking/IStaking.sol";
import { Gamerge } from "../contracts/Gamerge.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { console2 } from "forge-std/console2.sol";

contract DeployStaking is Script {
    function run() external {
        // load private key from env
        uint256 deployerKey = vm.envUint("NITHIN_TEST_PRIVATE_KEY");

        // params (replace with your actual token + owner addresses)
        address gmgToken = 0x1640ea2f58Df82a1F86f15AF1191fd825692C0ea;
        address owner = 0x8356D265646a397b2Dacf0e05A4973E7676597f4;

        vm.startBroadcast(deployerKey);

        // 1. Deploy implementation contract
        Staking stakingImpl = new Staking();

        // 2. Encode initializer calldata
        IStaking.InitParams memory params = IStaking.InitParams({
            gmgToken: gmgToken,
            owner: owner
        });

        bytes memory initData = abi.encodeWithSelector(
            Staking.initialize.selector,
            params
        );

        // 3. Deploy proxy with implementation and init data
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(stakingImpl),
            initData
        );

        vm.stopBroadcast();

        console2.log("Staking Implementation:", address(stakingImpl));
        console2.log("Staking Proxy:", address(proxy));
    }
}