// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { PresaleFactory } from "../contracts/presale/PresaleFactory.sol";
import { Presale } from "../contracts/presale/Presale.sol";
import { Vesting } from "../contracts/presale/Vesting.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@chainlink/brownie/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import "forge-std/console.sol";

contract DeployPresaleFactory is Script {
  // Network-specific addresses
  address constant BSC_CHAINLINK_BNB_PA =
    0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE; // BSC BNB/USD Price Feed
  address constant BSC_USDT = 0x55d398326f99059fF775485246999027B3197955;
  address constant BSC_GMG = 0xA3CBa8c94b758D56315Def513DEC5E75Ce05041a;

  // For testing
  ERC20Mock public mockUSDT;
  ERC20Mock public mockGMG;
  MockV3Aggregator public mockBnbPriceAggregator;

  function run() public {
    if (block.chainid == 31337) {
      vm.startBroadcast();
    } else {
      // For testnet/mainnet, use private key from .env
      vm.startBroadcast( vm.envUint("HOLESKY_PRIVATE_KEY"));
    }

    // Deploy implementation contracts
    Presale presaleImpl = new Presale();
    Vesting vestingImpl = new Vesting();

    // Get network-specific addresses or deploy mocks for local testing
    (address bnbPa, address usdt, address gmg) = getNetworkAddresses();

    // Deploy PresaleFactory
    PresaleFactory factory = new PresaleFactory(presaleImpl, vestingImpl, bnbPa, gmg, usdt);
    // giving allowance of 19.5 million GMG tokens to the factory
    ERC20Mock gamerge = ERC20Mock(gmg);
    bool success = gamerge.approve(address(factory), 21_500_000 * 1e18);
    require(success, "couldn't approve factory for GMG");

    // create the first presale stage
    // _tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages, _presaleStage
    address presale1Address = factory.createPresale(0.01 * 1e18, 1_000_000 * 1e18, 30 days, 36, 20, 1);

    vm.stopBroadcast();

    // Log deployed addresses
    console2.log("Network:", getNetworkName());
    console2.log("Deployed PresaleFactory at:", address(factory));
    console2.log("Deployed Presale Stage 1 at:", presale1Address);
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
      console.log("minted to msg.sender", msg.sender);
      mockGMG.mint(msg.sender, 100_000_000 * 1e18); // Mint 100M GMG

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
