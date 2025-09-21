// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

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
        address gmgToken = 0x10247f7A10aAF32D94691F6FbE51d8aC434a0d8E;
        address owner = 0x8356D265646a397b2Dacf0e05A4973E7676597f4;

        vm.startBroadcast(deployerKey);

        Staking stakingImpl = new Staking();

        IStaking.InitParams memory params = IStaking.InitParams({
            gmgToken: gmgToken,
            owner: owner
        });

        IStaking newStaking = IStaking(
            address(
                new ERC1967Proxy(
                    address(stakingImpl), abi.encodeCall(IStaking.initialize, (params))
                )
            )
        );

        // bytes memory initData = abi.encodeWithSelector(
        //     Staking.initialize.selector,
        //     params
        // );

        // // 3. Deploy proxy with implementation and init data
        // ERC1967Proxy proxy = new ERC1967Proxy(
        //     address(stakingImpl),
        //     initData
        // );

        vm.stopBroadcast();

        console2.log("Staking Implementation:", address(stakingImpl));
        console2.log("Staking Proxy:", address(newStaking));
    }
}