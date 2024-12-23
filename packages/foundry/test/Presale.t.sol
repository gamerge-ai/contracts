// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
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
        bnbPriceAggregator = new MockV3Aggregator(18, 1000 * 1e18);

        factory = new PresaleFactory();
        address presaleAddress = factory.initiatePresale(
            tokenPrice,
            tokenAllocation,
            cliff,
            vestingMonths,
            tgePercentages, 
            address(bnbPriceAggregator), 
            address(gmg),
            address(usdt)
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

    function testFuzz_BuyWithBnb(uint256 bnbAmount) public {

        vm.assume(bnbAmount > 1* 1e14 && bnbAmount < 1 * 1e18);
        uint256 bnbInUsd = 1000 * 1e6;
        uint256 valueInUsd = (bnbInUsd * bnbAmount) / 1e18; 
        uint256 expectedGMG = (valueInUsd * 1e18) / (tokenPrice * 1e6);

        vm.deal(participant, bnbAmount);

        vm.prank(owner);
        presale.startPresale();
        vm.prank(participant);
        presale.buyWithBnb{value: bnbAmount}(referral);

        uint256 expectedContractBalance = bnbAmount - ((bnbAmount * 10) / 100);
        assertEq(address(presale).balance, expectedContractBalance, "Presale contract balance mismatch");
        assertEq(address(referral).balance, ((bnbAmount * 10) / 100));

        (uint256 totalGMG, , , , , ) = presale.participantDetails(participant);  
        assertEq(totalGMG, expectedGMG, "GMG mismatch");
    }

    function test_BuyWithBnb() public {

        // vm.assume(bnbAmount == 1 * 1e18);
        uint256 bnbAmount = 1 * 1e18;
        uint256 bnbInUsd = 1000 * 1e6;
        uint256 expectedGMG = (bnbInUsd * bnbAmount) / (tokenPrice * 1e6);

        vm.deal(participant, bnbAmount);

        vm.prank(owner);
        presale.startPresale();
        vm.prank(participant);
        presale.buyWithBnb{value: bnbAmount}(referral);

        uint256 expectedContractBalance = bnbAmount - ((bnbAmount * 10) / 100);
        assertEq(address(presale).balance, expectedContractBalance, "Presale contract balance mismatch");
        assertEq(address(referral).balance, ((bnbAmount * 10) / 100));

        (uint256 totalGMG, , , , , ) = presale.participantDetails(participant);  
        assertEq(totalGMG, expectedGMG, "GMG mismatch");
    }

    function testFuzz_BuyWithUsdt(uint256 usdtAmount) public {
        vm.assume(usdtAmount <= 1000 * 1e6);
        uint256 expectedGMG = (usdtAmount * 1e18) / (tokenPrice * 1e6);

        vm.startPrank(owner);
        presale.startPresale();
        usdt.transfer(participant, usdtAmount);
        vm.stopPrank();

        vm.startPrank(participant);
        usdt.approve(address(presale), usdtAmount);
        presale.buyWithUsdt(usdtAmount, referral);
    
        uint256 expectedContractUsdtBalance = usdtAmount - ((usdtAmount * 10) / 100);
        assertEq(usdt.balanceOf(address(presale)), expectedContractUsdtBalance, "Presale contract USDT balance mismatch");
        assertEq(usdt.balanceOf(referral), ((usdtAmount * 10) / 100));

        (uint256 totalGMG, , , , , ) = presale.participantDetails(participant);  
        assertEq(totalGMG, expectedGMG, "GMG mismatch");

        vm.stopPrank();
    }
}