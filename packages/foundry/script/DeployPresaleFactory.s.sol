// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { PresaleFactory } from "../contracts/presale/PresaleFactory.sol";
import { Presale } from "../contracts/presale/Presale.sol";
import { Vesting } from "../contracts/presale/Vesting.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@chainlink/brownie/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import { Defender } from "openzeppelin-foundry-upgrades/Defender.sol";

contract DeployPresaleFactory is Script {
  // Network-specific addresses
  address constant BSC_CHAINLINK_BNB_PA =
    0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // BSC BNB/USD Price Feed
  address constant BSC_USDT = 0x55d398326f99059fF775485246999027B3197955;
  address constant BSC_GMG = address(111);

  // For testing
  ERC20Mock public mockUSDT;
  ERC20Mock public mockGMG;
  MockV3Aggregator public mockBnbPriceAggregator;

  function run() public {
    uint256 deployerPrivateKey;
    if (block.chainid == 31337) {
      // Local Anvil network
      // Use the first test account that Anvil provides
      deployerPrivateKey =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    } else {
      // For testnet/mainnet, use private key from .env
      deployerPrivateKey = vm.envUint("HOLESKY_PRIVATE_KEY");
    }
    vm.startBroadcast(deployerPrivateKey);

    // Deploy implementation contracts
    Presale presaleImpl = new Presale();
    Vesting vestingImpl = new Vesting();

    // Get network-specific addresses or deploy mocks for local testing
    (address bnbPa, address usdt, address gmg) = getNetworkAddresses();

    // Deploy PresaleFactory
    PresaleFactory factory =
      new PresaleFactory(presaleImpl, vestingImpl, bnbPa, gmg, usdt);

    vm.stopBroadcast();

    // Log deployed addresses
    console2.log("Network:", getNetworkName());
    console2.log("Deployed PresaleFactory at:", address(factory));
    console2.log("Presale Implementation at:", address(presaleImpl));
    console2.log("Vesting Implementation at:", address(vestingImpl));
    console2.log("BNB Price Aggregator at:", bnbPa);
    console2.log("USDT Token at:", usdt);
    console2.log("GMG Token at:", gmg);
  }

  function getNetworkAddresses()
    internal
    returns (address bnbPa, address usdt, address gmg)
  {
    if (block.chainid == 56) {
      // BSC
      return (BSC_CHAINLINK_BNB_PA, BSC_USDT, BSC_GMG);
    } else if (block.chainid == 31337 || block.chainid == 17000) {
      // Local Anvil/Hardhat or Holesky
      mockUSDT = new ERC20Mock();
      mockGMG = new ERC20Mock();
      mockBnbPriceAggregator = new MockV3Aggregator(8, 300 * 1e8); // $300 BNB price with 8 decimals

      // Initialize mocks
      mockUSDT.mint(msg.sender, 1000000 * 1e18); // Mint 1M USDT
      mockGMG.mint(msg.sender, 1000000 * 1e18); // Mint 1M GMG

      return
        (address(mockBnbPriceAggregator), address(mockUSDT), address(mockGMG));
    } else {
      revert("Unsupported network");
    }
  }

  function getNetworkName() internal view returns (string memory) {
    if (block.chainid == 17000) return "Holesky";
    if (block.chainid == 56) return "BSC Mainnet";
    if (block.chainid == 31337) return "Local Anvil";
    return "Unknown Network";
  }
}
