// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../contracts/presale/Vesting.sol";
import "../contracts/presale/interfaces/IVesting.sol";
import "../contracts/presale/interfaces/IPresale.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";


// Mock Presale contract for testing
contract MockPresale {
  uint256 private _tgeTriggeredAt;

  function setTgeTriggeredAt(
    uint256 timestamp
  ) external {
    _tgeTriggeredAt = timestamp;
  }

  function tgeTriggeredAt() external view returns (uint256) {
    return _tgeTriggeredAt;
  }
}

contract VestingTest is Test {
  Vesting public implementation;
  Vesting public vesting;
  MockPresale public presale;
  ERC1967Proxy public proxy;

  address public beneficiary;
  address public owner;
  uint64 public constant CLIFF_PERIOD = 30 days;
  uint256 public constant VESTING_MONTHS = 12;
  uint256 public constant TOTAL_ALLOCATION = 1000000 ether;

  event ERC20Released(address indexed token, uint256 amount);

  function setUp() public {
    // Setup accounts
    beneficiary = makeAddr("beneficiary");
    owner = makeAddr("owner");

    // Deploy mock presale
    presale = new MockPresale();

    // Deploy implementation
    implementation = new Vesting();

    // Deploy proxy
    bytes memory initData = abi.encodeWithSelector(
      Vesting.initialize.selector,
      presale,
      CLIFF_PERIOD,
      beneficiary,
      VESTING_MONTHS,
      owner
    );

    proxy = new ERC1967Proxy(address(implementation), initData);

    // Get the proxy as Vesting contract
    vesting = Vesting(payable(proxy));
  }

  function testInitialization() public view {
    assertEq(vesting.owner(), beneficiary);
    assertEq(vesting.duration(), VESTING_MONTHS * 30 days);
  }

  function testStartTime() public {
    // Initially TGE not triggered
    assertEq(vesting.start(), CLIFF_PERIOD);

    // Set TGE trigger time
    uint256 tgeTime = block.timestamp;
    presale.setTgeTriggeredAt(tgeTime);

    assertEq(vesting.start(), tgeTime + CLIFF_PERIOD);
  }

  function testTokenVesting() public {
    // Deploy a mock ERC20 token and mint to vesting contract
    ERC20Mock token = new ERC20Mock();
    token.mint(address(vesting), TOTAL_ALLOCATION);

    // Set TGE trigger time to current block timestamp
    uint256 tgeTime = block.timestamp;
    presale.setTgeTriggeredAt(tgeTime);

    // Wait for cliff period plus some vesting duration to ensure tokens are releasable
    vm.warp(tgeTime + CLIFF_PERIOD + 30 days); // Add extra time after cliff

    // Check initial releasable amount
    uint256 initialReleasable = vesting.releasable(address(token));
    assertGt(initialReleasable, 0);

    // Release tokens
    vm.prank(beneficiary);
    vm.expectEmit(true, true, false, true);
    emit ERC20Released(address(token), initialReleasable);
    vesting.release(address(token));

    // Verify released amount
    assertEq(token.balanceOf(beneficiary), initialReleasable);

    // Warp to middle of vesting period
    vm.warp(tgeTime + CLIFF_PERIOD + (VESTING_MONTHS * 30 days / 2));

    // Release more tokens
    uint256 midTermReleasable = vesting.releasable((address(token)));
    vm.prank(beneficiary);
    vesting.release(address(token));

    // Verify released amount
    assertGt(token.balanceOf(beneficiary), initialReleasable);
    assertEq(
      token.balanceOf(beneficiary), initialReleasable + midTermReleasable
    );
  }

  function testBNBSupportDisabled() public {
    vm.expectRevert(IVesting.bnb_not_supported.selector);
    vesting.released();

    vm.expectRevert(IVesting.bnb_not_supported.selector);
    vesting.releasable();

    vm.expectRevert(IVesting.bnb_not_supported.selector);
    vesting.release();

    vm.expectRevert(IVesting.bnb_not_supported.selector);
    vesting.vestedAmount(0);

    // Test receive function
    vm.expectRevert(IVesting.bnb_not_supported.selector);
    (bool success,) = payable(address(vesting)).call{ value: 1 ether }("");
  }

  function testVestingScheduleBeforeTGE() public {
    ERC20Mock token = new ERC20Mock();
    token.mint(address(vesting), TOTAL_ALLOCATION);

    // TGE not triggered yet
    assertEq(presale.tgeTriggeredAt(), 0);

    // Check that no tokens are releasable
    assertEq(vesting.releasable((address(token))), 0);
  }
}

