// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../contracts/presale/Presale.sol";
import "../contracts/presale/PresaleFactory.sol";
import "../contracts/presale/interfaces/IPresale.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockPriceAggregator.sol";

contract PresaleTest is Test {
  Presale public presaleImpl;
  PresaleFactory public factory;
  MockERC20 public gmg;
  MockERC20 public usdt;
  MockPriceAggregator public priceAggregator;
  address public owner;
  address public user1;
  address public user2;

  event PresaleStarted(uint8 presaleStage);
  event BoughtWithBnb(
    address indexed participant, uint256 bnbAmount, uint256 gmgAmount
  );
  event BoughtWithUsdt(
    address indexed participant, uint256 usdtAmount, uint256 gmgAmount
  );

  function setUp() public {
    owner = address(this);
    user1 = makeAddr("user1");
    user2 = makeAddr("user2");

    gmg = new MockERC20("GMG Token", "GMG");
    usdt = new MockERC20("USDT", "USDT");
    priceAggregator = new MockPriceAggregator();

    presaleImpl = new Presale();
    factory = new PresaleFactory(
      IPresale(address(presaleImpl)),
      IVesting(address(0)), // Will be set later
      address(priceAggregator),
      address(gmg),
      address(usdt)
    );

    // Initialize presale parameters
    uint16 tokenPrice = 100; // $0.1
    uint88 tokenAllocation = 1_000_000 * 1e18;
    uint24 cliff = 180 days;
    uint8 vestingMonths = 12;
    uint8 tgePercentages = 10;
    uint8 presaleStage = 1;

    // Mint tokens to owner
    gmg.mint(owner, tokenAllocation);
    gmg.approve(address(factory), tokenAllocation);

    // Create presale
    factory.createPresale(
      tokenPrice,
      tokenAllocation,
      cliff,
      vestingMonths,
      tgePercentages,
      presaleStage
    );

    IPresale[] memory presales = factory.getAllPresales();
    presaleImpl = Presale(payable(address(presales[0])));
  }

  function testInitialization() public {
    assertEq(address(presaleImpl.gmg()), address(gmg));
    assertEq(presaleImpl.owner(), owner);

    (uint256 price,,,,,) = presaleImpl.presaleInfo();
    assertEq(price, 100);
  }

  function testBuyWithBnb() public {
    vm.deal(user1, 10 ether);

    vm.startPrank(owner);
    presaleImpl.startPresale();
    vm.stopPrank();

    vm.startPrank(user1);
    vm.expectEmit(true, false, false, true);
    emit BoughtWithBnb(user1, 1 ether, 30_000 * 1e18); // Assuming 1 BNB = $3000
    presaleImpl.buyWithBnb{ value: 1 ether }(address(0));
    vm.stopPrank();

    assertEq(presaleImpl.gmgBought(), 30_000 * 1e18);
  }

  function testBuyWithUsdt() public {
    uint256 usdtAmount = 1000 * 1e6; // $1000
    usdt.mint(user1, usdtAmount);

    vm.startPrank(owner);
    presaleImpl.startPresale();
    vm.stopPrank();

    vm.startPrank(user1);
    usdt.approve(address(presaleImpl), usdtAmount);
    vm.expectEmit(true, false, false, true);
    emit BoughtWithUsdt(user1, usdtAmount, 10_000 * 1e18);
    presaleImpl.buyWithUsdt(usdtAmount, address(0));
    vm.stopPrank();

    assertEq(presaleImpl.gmgBought(), 10_000 * 1e18);
  }

  function testFuzz_BuyWithBnb(
    uint256 bnbAmount
  ) public {
    vm.assume(bnbAmount > 0.01 ether && bnbAmount < 100 ether);
    vm.deal(user1, bnbAmount);

    vm.startPrank(owner);
    presaleImpl.startPresale();
    vm.stopPrank();

    vm.startPrank(user1);
    presaleImpl.buyWithBnb{ value: bnbAmount }(address(0));
    vm.stopPrank();

    assertTrue(presaleImpl.gmgBought() > 0);
  }

  function testMaxPurchaseLimit() public {
    uint256 usdtAmount = 1001 * 1e6; // $1001 (above limit)
    usdt.mint(user1, usdtAmount);

    vm.startPrank(owner);
    presaleImpl.startPresale();
    vm.stopPrank();

    vm.startPrank(user1);
    usdt.approve(address(presaleImpl), usdtAmount);
    vm.expectRevert(IPresale.max_limit_exceeded.selector);
    presaleImpl.buyWithUsdt(usdtAmount, address(0));
    vm.stopPrank();
  }

  function testReferralBonus() public {
    uint256 usdtAmount = 1000 * 1e6;
    usdt.mint(user1, usdtAmount);

    vm.startPrank(owner);
    presaleImpl.startPresale();
    vm.stopPrank();

    vm.startPrank(user1);
    usdt.approve(address(presaleImpl), usdtAmount);
    presaleImpl.buyWithUsdt(usdtAmount, user2);
    vm.stopPrank();

    assertEq(presaleImpl.individualReferralUsdt(user2), 100 * 1e6); // 10% bonus
  }

  function testTGETrigger() public {
    vm.startPrank(owner);
    presaleImpl.triggerTGE();
    assertTrue(presaleImpl.isTgeTriggered());
    vm.expectRevert(IPresale.tge_already_triggered.selector);
    presaleImpl.triggerTGE();
    vm.stopPrank();
  }

  function testPresaleStartStop() public {
    vm.startPrank(owner);
    presaleImpl.startPresale();
    assertTrue(presaleImpl.isPresaleStarted());

    presaleImpl.stopPresale();
    assertFalse(presaleImpl.isPresaleStarted());
    vm.stopPrank();
  }
}
