// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/presale/Presale.sol";
import "../contracts/presale/PresaleFactory.sol";
import "../contracts/presale/Vesting.sol";
import "../contracts/presale/interfaces/IPresale.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@chainlink/brownie/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract PresaleTest is Test {
  Presale public presale;
  PresaleFactory public factory;
  Vesting public vesting;

  ERC20Mock public gmg;
  ERC20Mock public usdt;
  MockV3Aggregator public bnbPriceAggregator;

  address public owner = makeAddr("owner");
  address public participant = makeAddr("participant");
  address public referral = makeAddr("referral");

  uint256 public tokenPrice = 0.3 * 1e18;
  uint256 public tokenAllocation = 1_000_000 * 1e18;
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

  event PresaleStarted(uint8 presaleStage);
  event BoughtWithBnb(
    address indexed participant, uint256 bnbAmount, uint256 gmgAmount
  );
  event BoughtWithUsdt(
    address indexed participant, uint256 usdtAmount, uint256 gmgAmount
  );

  function setUp() public {
    vm.startPrank(owner);

    gmg = new ERC20Mock();
    gmg.mint(owner, 1_000_000_000_000 * 1e18);
    usdt = new ERC20Mock();
    usdt.mint(owner, 1_000_000_000 * 1e18);
    bnbPriceAggregator = new MockV3Aggregator(8, 69417247995);

    Presale presaleImpl = new Presale();
    Vesting vestingImpl = new Vesting();
    factory = new PresaleFactory(
      IPresale(address(presaleImpl)),
      IVesting(address(vestingImpl)),
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
    presale = Presale(payable(presaleAddress));
    vm.stopPrank();
  }

  function test_initialization() public view {
    assertEq(address(presale.gmg()), address(gmg), "GMG address mismatch");
    assertEq(address(presale._usdt()), address(usdt), "USDT address mismatch");
    assertEq(presale.owner(), owner, "owners are not same");
    (
      uint256 price,
      uint256 allocation,
      uint64 _cliff,
      uint8 _vestingMonths,
      uint8 _tgePercentages,
    ) = presale.presaleInfo();
    assertEq(allocation, tokenAllocation, "token allocation mismatch");
    assertEq(_cliff, cliff, "cliff mismatch");
    assertEq(_vestingMonths, vestingMonths, "vesting months mismatch");
    assertEq(_tgePercentages, tgePercentages, "tge percentages mismatch");
    assertEq(vestingMonths, vestingMonths, "vesting months mismatch");
    assertEq(price, tokenPrice, "token price mismatch");
    // assertEq(presale.presaleStartTime(), 0, "presale start time is not zero");
    assertEq(presale.isTgeTriggered(), false, "presale TGE already active");
    assertEq(presale.tgeTriggeredAt(), 0, "presale TGE start time is not zero");
  }

  function test_PresaleStartAndStop() public {
    vm.startPrank(owner);
    assertFalse(presale.isPresaleStarted(), "presale already started");
    presale.startPresale();
    assertTrue(presale.isPresaleStarted(), "presale not started");

    presale.stopPresale();
    assertFalse(presale.isPresaleStarted(), "presale already stopped");
    vm.stopPrank();
  }

  function test_BuyWithBnb(
    uint256 bnbAmount
  ) public {
    vm.assume(bnbAmount > 1 * 1e14 && bnbAmount < 1 * 1e18);
    vm.deal(participant, bnbAmount);
    uint256 bnbInUsd = 69417247995 * (10 ** 10);
    uint256 valueInUsd = (bnbInUsd * bnbAmount) / 1e18;
    uint256 expectedGMG = (valueInUsd * 1e18) / (tokenPrice);

    vm.startPrank(owner);
    presale.startPresale();
    vm.stopPrank();

    vm.startPrank(participant);
    presale.buyWithBnb{ value: bnbAmount }(referral);
    vm.stopPrank();

    emit BoughtWithBnb(participant, bnbAmount, expectedGMG);
    (uint256 totalGMG, uint256 releaseOnTGE, bool isParticipant) =
      presale.participantDetails(participant);
    assertEq(totalGMG, expectedGMG, "GMG mismatch");
    assertEq(
      releaseOnTGE,
      (expectedGMG * tgePercentages) / 100,
      "release on tge amount mismatch"
    );
    assertTrue(isParticipant, "isParticipant should be true");
  }

  function test_BuyWithUsdt(
    uint256 usdtAmount
  ) public {
    vm.assume(usdtAmount <= 1000 && usdtAmount > 1);
    uint256 expectedGMG = (usdtAmount * 1e18) / (tokenPrice);

    vm.startPrank(owner);
    presale.startPresale();
    usdt.transfer(participant, usdtAmount);
    vm.stopPrank();

    vm.startPrank(participant);

    usdt.approve(address(presale), usdtAmount);
    presale.buyWithUsdt(usdtAmount, referral);

    uint256 amountToReferral = (usdtAmount * 10) / 100;
    uint256 currentReferralAmount = presale.individualReferralUsdt(referral);
    uint256 expectedContractUsdtBalance = usdtAmount - ((usdtAmount * 10) / 100);
    assertEq(
      usdt.balanceOf(address(presale)) - currentReferralAmount,
      expectedContractUsdtBalance,
      "Presale contract USDT balance mismatch"
    );
    assertEq(currentReferralAmount, amountToReferral);

    (uint256 totalGMG, uint256 releaseOnTGE, bool isParticipant) =
      presale.participantDetails(participant);
    assertEq(totalGMG, expectedGMG, "GMG mismatch");
    assertEq(
      releaseOnTGE,
      (totalGMG * tgePercentages) / 100,
      "release on tge amount mismatch"
    );
    assertTrue(isParticipant);
    vm.stopPrank();
  }

  function test_triggerTGE() public {
    vm.startPrank(owner);
    presale.startPresale();
    assertEq(presale.isTgeTriggered(), false, "presale TGE already active");
    assertEq(presale.tgeTriggeredAt(), 0, "presale TGE start time is not zero");
    presale.triggerTGE();
    assertTrue(presale.isTgeTriggered());
    assertGt(
      presale.tgeTriggeredAt(), 0, "presale TGE start time shouldn't be zero"
    );
    vm.stopPrank();
  }

  function testFuzz_claimTGE(
    uint256 amountInUsd
  ) public {
    vm.assume(amountInUsd <= 1000e18 && amountInUsd > 1e18);
    vm.startPrank(owner);
    presale.startPresale();
    usdt.transfer(participant, amountInUsd);
    presale.triggerTGE();
    vm.stopPrank();

    vm.startPrank(participant);
    usdt.approve(address(presale), amountInUsd);
    presale.buyWithUsdt(amountInUsd, referral);
    (, uint256 releaseOnTGE,) = presale.participantDetails(participant);
    presale.claimTGE(participant);
    (, uint256 releaseOnTGEAfter,) = presale.participantDetails(participant);
    assertEq(
      gmg.balanceOf(participant),
      releaseOnTGE,
      "balanceOf(participant) and releaseOnTGE mismatch"
    );
    assertEq(
      releaseOnTGEAfter, 0, "release on tge should be zero after claiming TGE"
    );
  }

  function test_claimReferral(
    uint256 usdtAmount
  ) public {
    vm.assume(usdtAmount <= 1000 * 1e6 && usdtAmount > 1 * 1e6);
    vm.startPrank(owner);
    presale.startPresale();
    usdt.transfer(participant, usdtAmount);
    vm.stopPrank();

    vm.startPrank(participant);
    usdt.approve(address(presale), usdtAmount);
    presale.buyWithUsdt(usdtAmount, referral);
    vm.stopPrank();

    vm.startPrank(referral);
    uint256 usdtReferralAmount = (usdtAmount * 10) / 100;
    assertEq(
      presale.individualReferralUsdt(referral),
      usdtReferralAmount,
      "referral amount referral USDT balance mismatch"
    );
    presale.claimRefferalAmount(IPresale.ASSET.USDT);
    assertEq(
      usdt.balanceOf(referral),
      usdtReferralAmount,
      "referral USDT balance mismatch"
    );
    presale.claimRefferalAmount(IPresale.ASSET.BNB);
    vm.stopPrank();
    assertEq(
      presale.individualReferralUsdt(referral),
      0,
      "referral USDT balance mismatch"
    );
  }

  function test_claimVestingAmount(
    uint256 usdtAmount
  ) public {
    vm.assume(usdtAmount <= 1000 * 1e6 && usdtAmount > 1 * 1e6);

    (uint256 pricePerToken,,,,,) = presale.presaleInfo();

    uint256 gmgAmount = (usdtAmount * 1e18) / pricePerToken;
    uint256 expectedTgeRelease = (gmgAmount * (10 * 100)) / (10_000);
    console.log("purchasing gmg amount: ", gmgAmount);
    console.log("expected tge release: ", expectedTgeRelease);

    vm.startPrank(owner);
    presale.startPresale();
    usdt.transfer(participant, usdtAmount);
    vm.stopPrank();

    vm.startPrank(participant);
    usdt.approve(address(presale), usdtAmount);
    presale.buyWithUsdt(usdtAmount, referral);
    vm.stopPrank();

    Vesting vestingWallet = presale.vestingWallet(participant);

    // vesting wallet should not release anything
    uint256 beforeB = gmg.balanceOf(participant);
    vm.prank(participant);
    vestingWallet.release(address(gmg));
    uint256 afterB = gmg.balanceOf(participant);
    assertEq(beforeB, afterB, "0 gmg should be withdrawable before tge trigger");

    vm.startPrank(owner);
    presale.triggerTGE();
    console.log("Tge triggered at: ", presale.tgeTriggeredAt());
    vm.stopPrank();

    vm.startPrank(participant);
    (, uint256 releaseOnTGE,) = presale.participantDetails(participant);
    presale.claimTGE(participant);
    assertEq(expectedTgeRelease, releaseOnTGE, "TGE release mismatch");

    vm.expectRevert();
    presale.claimTGE(participant);
    vm.stopPrank();
    console.log("Tge triggered at: ", presale.tgeTriggeredAt());
    console.log("block.timestamp: ", block.timestamp);

    // vesting wallet should not release anything
    beforeB = gmg.balanceOf(participant);
    vm.prank(participant);
    vestingWallet.release(address(gmg));
    afterB = gmg.balanceOf(participant);
    assertEq(
      beforeB, afterB, "0 gmg should be withdrawable during cliff period"
    );

    // Wait for cliff period plus some vesting duration to ensure tokens are releasable
    vm.warp(presale.tgeTriggeredAt() + cliff + 30 days);
    console.log("Tge triggered at: ", presale.tgeTriggeredAt());
    console.log("block.timestamp: ", block.timestamp);

    uint256 releasableAmount = vestingWallet.releasable(address(gmg));
    console.log("releaseable amount: ", releasableAmount);

    assertGt(releasableAmount, 0, "No tokens releasable after cliff");

    vm.prank(participant);
    vestingWallet.release(address(gmg));

    uint256 participantBalance = gmg.balanceOf(participant);

    assertEq(
      participantBalance,
      releaseOnTGE + releasableAmount,
      "claiming vesting after one month should increase balance"
    );
  }
}
