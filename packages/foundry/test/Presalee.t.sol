// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/presale/Presale.sol";
import "../contracts/presale/PresaleFactory.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@chainlink/brownie/contracts/src/v0.8/tests/MockV3Aggregator.sol";
contract PresaleTest is Test {

    Presale public presaleImpl;
    PresaleFactory public factory;

    ERC20Mock public gmg;
    ERC20Mock public usdt;
    MockV3Aggregator public bnbPriceAggregator;

    address public owner = makeAddr("owner");
    address public participant = makeAddr("participant");
    address public referral = makeAddr("referral");

    uint16 public tokenPrice = 10000;
    uint88 public tokenAllocation = 1_000_000 * 1e18;
    uint64 public cliff = 30 days;
    uint8 public vestingMonths = 12;
    uint8 public tgePercentages = 10;
    uint8 public presaleStage = 1;

    struct Participant {
        uint256 totalGMG;
        uint256 withdrawnGMG;
        uint256 releaseOnTGE;
        uint256 claimableVestedGMG;
        uint256 lastVestedClaimedAt;
        bool isParticipant;
    }

    using console for *;

    event PresaleStarted(uint8 presaleStage);
    event BoughtWithBnb(address indexed participant, uint256 bnbAmount, uint256 gmgAmount);
    event BoughtWithUsdt(address indexed participant, uint256 usdtAmount, uint256 gmgAmount);

    function setUp() public {

        vm.startPrank(owner);

        gmg = new ERC20Mock();
        gmg.mint(owner, 1_000_000_000_000 * 1e18);
        usdt = new ERC20Mock();
        usdt.mint(owner, 1_000_000_000 * 1e18);
        bnbPriceAggregator = new MockV3Aggregator(18, 1000 * 1e18);

        presaleImpl = new Presale();
        factory = new PresaleFactory(
            IPresale(address(presaleImpl)),
            IVesting(address(0)), // Will be set later
            address(bnbPriceAggregator),
            address(gmg),
            address(usdt)
        );
        gmg.approve(address(factory), 1_000_000 * 1e18);
        address presaleAddress = factory.createPresale(
            tokenPrice,
            tokenAllocation,
            cliff,
            vestingMonths,
            tgePercentages, 
            presaleStage
        );
        presaleImpl = Presale(payable(presaleAddress));
        gmg.approve(presaleAddress, 1_000_000 * 1e18);
        usdt.approve(presaleAddress, 1_000_000 * 1e6);
        vm.stopPrank();
    }

    function test_initialization() view public {
        assertEq(address(presaleImpl.gmg()), address(gmg), "GMG address mismatch");
        assertEq(address(presaleImpl._usdt()), address(usdt), "USDT address mismatch");
        assertEq(presaleImpl.owner(), owner, "owners are not same");
        (uint256 price, uint256 allocation, uint64 _cliff, uint8 _vestingMonths, uint8 _tgePercentages, ) = presaleImpl.presaleInfo();
        assertEq(allocation, tokenAllocation, "token allocation mismatch");
        assertEq(_cliff, cliff, "cliff mismatch");
        assertEq(_vestingMonths, vestingMonths, "vesting months mismatch");
        assertEq(_tgePercentages, tgePercentages, "tge percentages mismatch");
        assertEq(vestingMonths, vestingMonths, "vesting months mismatch");
        assertEq(price, tokenPrice, "token price mismatch");
        // assertEq(presaleImpl.presaleStartTime(), 0, "presale start time is not zero");
        assertEq(presaleImpl.isTgeTriggered(), false, "presale TGE already active");
        assertEq(presaleImpl.tgeTriggeredAt(), 0, "presale TGE start time is not zero");
    }

    function test_PresaleStartAndStop() public {
        vm.startPrank(owner);
        assertFalse(presaleImpl.isPresaleStarted(), "presale already started");
        presaleImpl.startPresale();
        assertTrue(presaleImpl.isPresaleStarted(), "presale not started");

        presaleImpl.stopPresale();
        assertFalse(presaleImpl.isPresaleStarted(), "presale already stopped");
        vm.stopPrank();
    }

    // function test_StartPresale() public {
    //     vm.startPrank(owner);
    //     assertEq(presale.isActive(), false, "Presale already active");
    //     assertEq(presale.presaleStartTime(), 0, "presale start time is not zero");
    //     (uint256 startTime, bool isActive) = presale.startPresale();
    //     assertEq(owner, presale.owner(), "owners are not same");

    //     assertEq(isActive, true, "Presale should be active");
    //     assertEq(presale.presaleStartTime(), startTime, "Presale start time mismatch");
    //     // assertEq(address(presale), address(this), "both not same");
    //     // assertEq(factory.authorizedPresale(address(this)), true, "not authorized dude...");
    //     vm.stopPrank();
    // }

    // function test_BuyWithBnb(uint256 bnbAmount) public {

    //     vm.assume(bnbAmount > 1* 1e14 && bnbAmount < 1 * 1e18);
    //     uint256 bnbInUsd = 1000 * 1e6;
    //     uint256 valueInUsd = (bnbInUsd * bnbAmount) / 1e18; 
    //     uint256 expectedGMG = (valueInUsd * 1e18) / (tokenPrice);

    //     vm.deal(participant, bnbAmount);

    //     vm.prank(owner);
    //     presale.startPresale();
    //     vm.prank(participant);
    //     presale.buyWithBnb{value: bnbAmount}(referral);

    //     uint256 expectedContractBalance = bnbAmount - ((bnbAmount * 10) / 100);
    //     assertEq(address(presale).balance, expectedContractBalance, "Presale contract balance mismatch");
    //     assertEq(address(referral).balance, ((bnbAmount * 10) / 100));

    //     (uint256 totalGMG, , , , , ) = presale.participantDetails(participant);  
    //     assertEq(totalGMG, expectedGMG, "GMG mismatch");
    // }

    // function test_BuyWithUsdt(uint256 usdtAmount) public {
    //     vm.assume(usdtAmount <= 1000 && usdtAmount > 1);
    //     uint256 expectedGMG = (usdtAmount * 1e6 * 1e18) / (tokenPrice) ;

    //     vm.startPrank(owner);
    //     presale.startPresale();
    //     usdt.transfer(participant, usdtAmount);
    //     vm.stopPrank();

    //     vm.startPrank(participant);
    //     usdt.approve(address(presale), usdtAmount);
    //     presale.buyWithUsdt(usdtAmount, referral);
    
    //     uint256 expectedContractUsdtBalance = usdtAmount - ((usdtAmount * 10) / 100);
    //     assertEq(usdt.balanceOf(address(presale)), expectedContractUsdtBalance, "Presale contract USDT balance mismatch");
    //     assertEq(usdt.balanceOf(referral), ((usdtAmount * 10) / 100));

    //     (uint256 totalGMG, uint256 withdrawnGMG, uint256 releaseOnTGE, uint256 claimableVestedGMG, uint256 lastVestedClaimedAt, bool isParticipant) = presale.participantDetails(participant);  
    //     assertEq(totalGMG, expectedGMG, "GMG mismatch");
    //     assertEq(releaseOnTGE, (totalGMG * tgePercentages) /100, "release on tge amount mismatch");
    //     assertEq(claimableVestedGMG, (totalGMG * ( 100 - tgePercentages)) /100);
    //     assertTrue(isParticipant);
    //     assertEq(lastVestedClaimedAt, 0, "last vested should be zero");
    //     vm.stopPrank();
    // }

    // function test_triggerTGE() public {
    //     vm.startPrank(owner);
    //     presale.startPresale();
    //     assertEq(presale.isTgeTriggered(), false, "presale TGE already active");
    //     assertEq(presale.tgeTriggeredAt(), 0, "presale TGE start time is not zero");
    //     presale.triggerTGE();
    //     assertTrue(presale.isTgeTriggered());
    //     vm.stopPrank();
    // }

    // function testFuzz_claimTGE(uint256 amountInUsd) public {
    //     vm.assume(amountInUsd <= 1000 && amountInUsd > 1);
    //     vm.startPrank(owner);
    //     presale.startPresale();
    //     usdt.transfer(participant, amountInUsd);
    //     presale.triggerTGE();
    //     vm.stopPrank();

    //     vm.startPrank(participant);
    //     usdt.approve(address(presale), amountInUsd);
    //     presale.buyWithUsdt(amountInUsd, referral);
    //     (, , uint256 releaseOnTGE, , , ) = presale.participantDetails(participant);  
    //     presale.claimTGE(participant);
    //     (, uint256 withdrawnGMGAfter, uint256 releaseOnTGEAfter, , , ) = presale.participantDetails(participant);  
    //     assertEq(gmg.balanceOf(participant), releaseOnTGE, "balanceOf(participant) and releaseOnTGE mismatch");
    //     assertEq(gmg.balanceOf(participant), withdrawnGMGAfter, "withdrawn and balanceOf(participant) mismatch");
    //     assertEq(releaseOnTGEAfter, 0, "release on tge should be zero after claiming TGE");
    // }

    // function testFuzz_claimVestingAmount(uint256 amountInUsd) public {
    //     testFuzz_claimTGE(amountInUsd);
    //     vm.startPrank(participant);
    //     (uint256 totalGMG, uint256 withdrawnGMG, uint256 releaseOnTGE, uint256 claimableVestedGMG, , ) = presale.participantDetails(participant);  
    //     uint256 totalVestingAmount = (totalGMG * ((100 - tgePercentages))) / (100);
    //     uint256 monthlyClaimable = totalVestingAmount / vestingMonths;
    //     uint256 claimableAmount = claimableVestedGMG < monthlyClaimable ? 
    //                               claimableVestedGMG : monthlyClaimable;
    //     uint256 _cliff = cliff;
    //     vm.warp(block.timestamp + cliff);
    //     uint256 tgeTriggeredAtSlot = 8;
    //     vm.store(address(presale), bytes32(tgeTriggeredAtSlot), bytes32(block.timestamp - _cliff));
    //     presale.claimVestingAmount(participant);
    //     (uint256 totalGMGAfter, uint256 withdrawnGMGAfter, uint256 releaseOnTGEAfter, uint256 claimableVestedGMGAfter, , ) = presale.participantDetails(participant);
    //     assertEq(gmg.balanceOf(participant), withdrawnGMGAfter, "withdrawn and balanceOf(participant) mismatch");
    //     assertEq(claimableVestedGMGAfter, (claimableVestedGMG - claimableAmount), "claimableVestedGMGAfter and (vestedAmount + claimed amount) mismatch");
    // }
}