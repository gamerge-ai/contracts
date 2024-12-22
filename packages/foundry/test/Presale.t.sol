// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/presale/Presale.sol";
import "../contracts/presale/PresaleFactory.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
// import "@chainlink/contracts/src/interfaces/test/MockV3AggregatorInterface.sol";
import "@chainlink/brownie/contracts/src/v0.8/tests/MockV3Aggregator.sol";
contract PresaleTest is Test {

    Presale public presale;
    PresaleFactory public factory;

    ERC20Mock public gmg;
    ERC20Mock public usdt;
    MockV3Aggregator public bnbPriceAggregator;

    address public owner = makeAddr("owner");
    address public participant = makeAddr("participant");
    address public referral = makeAddr("referral");

    uint16 public tokenPrice = 1;
    uint88 public tokenAllocation = 1_000_000 * 1e18;
    uint24 public cliff = 30 days;
    uint8 public vestingMonths = 12;
    uint8 public tgePercentages = 10;

    function setUp() public {

        vm.startPrank(owner);

        gmg = new ERC20Mock();
        gmg.mint(owner, 1_000_000_000_000 * 1e18);
        usdt = new ERC20Mock();
        usdt.mint(owner, 1_000_000_000 * 1e18);
        bnbPriceAggregator = new MockV3Aggregator(18, 600 * 1e18);

        factory = new PresaleFactory();
        address presaleAddress = factory.initiatePresale(
            100,
            1_000_000 * 1e18,
            60 days,
            12,
            20, 
            address(bnbPriceAggregator), 
            address(gmg),
            address(usdt)
            // address(factory)
        );
        presale = Presale(payable(presaleAddress));
        gmg.approve(address(presale), 1_000_000 * 1e18);
        usdt.approve(address(presale), 1_000_000 * 1e6);
        gmg.transfer(address(presale), tokenAllocation);
        vm.stopPrank();
    }

    function testFuzz_StartPresale() public {
        vm.startPrank(owner);
        assertEq(presale.isActive(), false, "Presale already active");
        assertEq(presale.presaleStartTime(), 0, "presale start time is not zero");
        (uint256 startTime, bool isActive) = presale.startPresale();
        assertEq(owner, presale.owner(), "owners are not same");

        assertEq(isActive, true, "Presale should be active");
        assertEq(presale.presaleStartTime(), startTime, "Presale start time mismatch");
        // assertEq(address(presale), address(this), "both not same");
        // assertEq(factory.authorizedPresale(address(this)), true, "not authorized dude...");
        vm.stopPrank();
    }

    function testFuzz_BuyWithBnb() public {
        uint256 bnbAmount = 1 * 1e10;
        uint256 bnbInUsd = 600 * 1e6;
        uint256 expectedGMG = (bnbInUsd / tokenPrice) * 1e18;

        vm.deal(participant, bnbAmount);
        // assertEq(gmg.balanceOf(address(presale),  );)

        vm.prank(owner);
        presale.startPresale();
        vm.prank(participant);
        presale.buyWithBnb{value: bnbAmount}(referral);
 
    }
}