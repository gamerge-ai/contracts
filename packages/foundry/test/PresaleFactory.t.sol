// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../contracts/presale/PresaleFactory.sol";
import "../contracts/presale/Presale.sol";
import "../contracts/presale/Vesting.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@chainlink/brownie/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract PresaleFactoryTest is Test {
  PresaleFactory public factory;
  Presale public presaleImpl;
  Vesting public vestingImpl;
  ERC20Mock public gmg;
  ERC20Mock public usdt;
  MockV3Aggregator public priceAggregator;
  address public owner;
  address public user1;

  event NewPresaleCreated(IPresale indexed presaleAddress);

  function setUp() public {
    owner = address(this);
    user1 = makeAddr("user1");

    gmg = new ERC20Mock();
    usdt = new ERC20Mock();
    priceAggregator = new MockV3Aggregator(8, 69417247995);

    presaleImpl = new Presale();
    vestingImpl = new Vesting();

    factory = new PresaleFactory(
      IPresale(address(presaleImpl)),
      IVesting(address(vestingImpl)),
      address(priceAggregator),
      address(gmg),
      address(usdt)
    );

    gmg.mint(owner, 100_000_000 * 1e18);
    gmg.approve(address(factory), type(uint256).max);
  }

  function testCreatePresale() public {
    uint256 tokenPrice = 0.01 * 1e18;
    uint256 tokenAllocation = 1_000_000 * 1e18;
    uint64 cliff = 180 days;
    uint8 vestingMonths = 12;
    uint8 tgePercentages = 10;
    uint8 presaleStage = 1;

    vm.expectEmit(false, false, false, false);
    emit NewPresaleCreated(IPresale(address(0))); // Can't predict exact address

    factory.createPresale(
      tokenPrice,
      tokenAllocation,
      cliff,
      vestingMonths,
      tgePercentages,
      presaleStage
    );

    IPresale[] memory presales = factory.getAllPresales();
    assertEq(presales.length, 1);
    assertTrue(factory.validPresale(presales[0]));
  }

  function testFuzz_CreatePresale(
    uint16 tokenPrice,
    uint88 tokenAllocation,
    uint24 cliff,
    uint8 vestingMonths,
    uint8 tgePercentages
  ) public {
    vm.assume(tokenPrice > 0 && tokenPrice < 10000); // $0.01 to $100
    vm.assume(
      tokenAllocation > 1000 * 1e18 && tokenAllocation < 100_000_000 * 1e18
    );
    vm.assume(cliff < 365 days);
    vm.assume(vestingMonths > 0 && vestingMonths <= 60);
    vm.assume(tgePercentages > 0 && tgePercentages <= 100);

    factory.createPresale(
      tokenPrice, tokenAllocation, cliff, vestingMonths, tgePercentages, 1
    );

    IPresale[] memory presales = factory.getAllPresales();
    assertEq(presales.length, 1);
  }

  function testUpdateImplementations() public {
    address newPresaleImpl = address(new Presale());
    address newVestingImpl = address(new Vesting());

    factory.updatePresaleImpl(newPresaleImpl);
    factory.updateVestingImpl(newVestingImpl);

    vm.expectRevert(PresaleFactory.zero_address.selector);
    factory.updatePresaleImpl(address(0));

    vm.expectRevert(PresaleFactory.zero_address.selector);
    factory.updateVestingImpl(address(0));
  }

  function testStartStopAllPresales() public {
    // Create multiple presales
    for (uint8 i = 0; i < 3; i++) {
      factory.createPresale(100, 1_000_000 * 1e18, 180 days, 12, 10, i + 1);
    }

    factory.startAllPresales();
    IPresale[] memory presales = factory.getAllPresales();
    for (uint8 i = 0; i < presales.length; i++) {
      assertTrue(presales[i].isPresaleStarted());
    }

    factory.stopAllPresales();
    for (uint8 i = 0; i < presales.length; i++) {
      assertFalse(presales[i].isPresaleStarted());
    }
  }

  function testTriggerTgeOnAllPresales() public {
    // Create multiple presales
    for (uint8 i = 0; i < 3; i++) {
      factory.createPresale(100, 1_000_000 * 1e18, 180 days, 12, 10, i + 1);
    }

    factory.triggerTgeOnAllPresales();
    IPresale[] memory presales = factory.getAllPresales();
    for (uint8 i = 0; i < presales.length; i++) {
      assertTrue(presales[i].isTgeTriggered());
    }
  }

  function testUpdateTotalBought() public {
    factory.createPresale(100, 1_000_000 * 1e18, 180 days, 12, 10, 1);
    IPresale[] memory presales = factory.getAllPresales();

    vm.expectRevert(PresaleFactory.unauthorized_presale.selector);
    vm.prank(user1);
    factory.updateTotalBought(user1, 1000 * 1e6);

    vm.prank(address(presales[0]));
    factory.updateTotalBought(user1, 1000 * 1e6);
    assertEq(factory.getTotalBought(user1), 1000 * 1e6);
  }
}
