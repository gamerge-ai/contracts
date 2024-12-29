// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/presale/Presale.sol";
import "../contracts/presale/PresaleFactory.sol";
import "../contracts/presale/Vesting.sol";
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

  uint16 public tokenPrice = 1000;
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
    bnbPriceAggregator = new MockV3Aggregator(18, 1000 * 1e18);

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
    uint256 bnbInUsd = 1000 * 1e6;
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
      assertGt(presale.tgeTriggeredAt(), 0, "presale TGE start time shouldn't be zero");
      vm.stopPrank();
  }

  function testFuzz_claimTGE(uint256 amountInUsd) public {
      vm.assume(amountInUsd <= 1000 && amountInUsd > 1);
      vm.startPrank(owner);
      presale.startPresale();
      usdt.transfer(participant, amountInUsd);
      presale.triggerTGE();
      vm.stopPrank();

      vm.startPrank(participant);
      usdt.approve(address(presale), amountInUsd);
      presale.buyWithUsdt(amountInUsd, referral);
      (, uint256 releaseOnTGE,  ) = presale.participantDetails(participant);
      presale.claimTGE(participant);
      (, uint256 releaseOnTGEAfter,  ) = presale.participantDetails(participant);
      assertEq(gmg.balanceOf(participant), releaseOnTGE, "balanceOf(participant) and releaseOnTGE mismatch");
      assertEq(releaseOnTGEAfter, 0, "release on tge should be zero after claiming TGE");
  }
}
