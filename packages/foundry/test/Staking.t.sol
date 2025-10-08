// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../contracts/staking/Staking.sol";
import "../contracts/staking/IStaking.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Gamerge is ERC20 {
    constructor(uint256 initialSupply) ERC20("GamergToken", "GMG") {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract StakingTest is Test {
    Staking stakingImpl;
    IStaking staking;
    Gamerge public gmg;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        gmg = new Gamerge(1e24); 
        stakingImpl = new Staking();

        IStaking.InitParams memory params = IStaking.InitParams({
            gmgToken: address(gmg),
            owner: owner
        });

        staking = IStaking(
            address(
                new ERC1967Proxy(
                    address(stakingImpl), abi.encodeCall(IStaking.initialize, (params))
                )
            )
        );


        gmg.mint(user1, 1e22); // 10k GMG
        gmg.mint(user2, 1e22); // 10k GMG
    }

    // ----------------------------
    // Basic staking tests
    // ----------------------------
    function testStake() public {
        vm.startPrank(user1);
        gmg.approve(address(staking), 1000 ether);
        staking.stake(1000 ether, IStaking.StakingPeriod.THREE_MONTHS);
        Staking.StakeInfo[] memory stakes = staking.getUserStakes(user1);
        assertEq(stakes[0].amount, 1000 ether);
        assertEq(stakes[0].stakeId, 0);
        vm.stopPrank();
    }

    function test_Revert_StakeZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(IStaking.InvalidAmount.selector);
        staking.stake(0, IStaking.StakingPeriod.THREE_MONTHS);
    }

    // ----------------------------
    // Unstake tests
    // ----------------------------
    function testEarlyUnstakePenalty() public {
        vm.startPrank(user1);
        gmg.approve(address(staking), 1000 ether);
        staking.stake(1000 ether, IStaking.StakingPeriod.NINE_MONTHS);

        Staking.StakeInfo memory stakeInfo = staking.getStakeInfo(user1, 0);
        assertTrue(stakeInfo.isActive);

        uint256 userBalanceBefore = gmg.balanceOf(user1);
        staking.unstake(0); // early unstake
        uint256 userBalanceAfter = gmg.balanceOf(user1);

        uint256 expected = 1000 ether - ((1000 ether * 1000) / 10000); // 10% penalty
        assertEq(userBalanceAfter - userBalanceBefore, expected);

        stakeInfo = staking.getStakeInfo(user1, 0);
        assertFalse(stakeInfo.isActive);
        vm.stopPrank();
    }

    function testNormalUnstakeAfterMaturity() public {
        vm.startPrank(user1);
        gmg.approve(address(staking), 1000 ether);
        staking.stake(1000 ether, IStaking.StakingPeriod.THREE_MONTHS);

        vm.warp(block.timestamp + 90 days);

        uint256 rewards = staking.getAvailableRewards(user1, 0);
        uint256 userBalanceBefore = gmg.balanceOf(user1);
        gmg.mint(address(staking), 1000 ether);
        staking.unstake(0);
        uint256 userBalanceAfter = gmg.balanceOf(user1);

        assertEq(userBalanceAfter - userBalanceBefore, 1000 ether + rewards);

        Staking.StakeInfo memory stakeInfo = staking.getStakeInfo(user1, 0);
        assertFalse(stakeInfo.isActive);
        vm.stopPrank();
    }

    function test_Revert_UnstakeNotOwner() public {
        vm.startPrank(user1);
        gmg.approve(address(staking), 1000 ether);
        staking.stake(1000 ether, IStaking.StakingPeriod.THREE_MONTHS);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(IStaking.StakeNotFound.selector);
        staking.unstake(0);
    }

    // ----------------------------
    // Pause/unpause tests
    // ----------------------------
    function testPauseAndUnpause() public {
        staking.pause();
        assertTrue(staking.isPaused());

        staking.unpause();
        assertFalse(staking.isPaused());
    }

    function test_Revert_StakeWhenPaused() public {
        staking.pause();
        vm.startPrank(user1);
        vm.expectRevert();
        staking.stake(1000 ether, IStaking.StakingPeriod.THREE_MONTHS);
    }

    // ----------------------------
    // Emergency withdraw
    // ----------------------------
    function testEmergencyWithdraw() public {
        gmg.mint(address(staking), 1000 ether);
        uint256 balanceBefore = gmg.balanceOf(owner);
        staking.emergencyWithdraw(IERC20(address(gmg)), owner, 1000 ether);
        uint256 balanceAfter = gmg.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, 1000 ether);
    }

    // ----------------------------
    // Fuzz testing
    // ----------------------------
    function testFuzzStake(uint256 amount, uint8 period) public {
        vm.assume(amount > 0 && amount < 1e22);
        vm.assume(period <= 3);

        vm.startPrank(user1);
        gmg.approve(address(staking), amount);
        staking.stake(amount, IStaking.StakingPeriod(period));

        Staking.StakeInfo memory s = staking.getStakeInfo(user1, 0);
        assertEq(s.amount, amount);
        assertEq(uint256(s.period), period);
        vm.stopPrank();
    }
}
