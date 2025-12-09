// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../contracts/team/Team.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract GMGToken is ERC20 {
    constructor() ERC20("Gamerge Token", "GMG") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TeamContractTest is Test {
    GMGToken public gmg;
    TeamContract public team;
    address public ownerAddr;
    address public alice;
    address public bob;
    uint256 private constant SECONDS_PER_MONTH = 30 days;

    function setUp() public {
        ownerAddr = address(this);
        alice = address(0xA11CE);
        bob = address(0xB0B);

        gmg = new GMGToken();
        gmg.mint(ownerAddr, 1_000_000 ether);


        team = new TeamContract(address(gmg), ownerAddr);
    }

    /* -----------------------
       Helper utilities
       ----------------------- */

    function _addMember(
        address who,
        string memory name,
        uint256 allocation,
        uint256 cliffMonths,
        uint256 vestingMonths
    ) internal {
        team.addTeamMember(who, name, allocation, cliffMonths, vestingMonths);
    }

    function _fundContract(uint256 amount) internal {
        gmg.transfer(address(team), amount);
    }

    /* ========== ADD MEMBER / PARAMS ========== */

    function testAddMemberSuccess() public {
        uint256 alloc = 1000 ether;
        _addMember(alice, "alice", alloc, 1, 12);
        (
            address memberAddr,
            string memory name,
            uint256 allocation,
            uint256 remaining,
            uint256 cliffMonths,
            uint256 vestingMonths,
            uint256 startTimestamp,
            uint256 withdrawn,
            bool isActive,
            uint256 claimable
        ) = team.getMember(alice);

        assertEq(memberAddr, alice);
        assertEq(allocation, alloc);
        assertEq(remaining, alloc);
        assertEq(cliffMonths, 1);
        assertEq(vestingMonths, 12);
        assertEq(withdrawn, 0);
        assertTrue(isActive);
        assertEq(claimable, 0);
        assertGt(startTimestamp, 0);
    }

    function testAddMemberZeroAddressReverts() public {
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidAddress()"))));
        team.addTeamMember(address(0), "bad", 100, 0, 1);
    }

    function testAddMemberInvalidParamsReverts() public {
        // zero allocation
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidParams()"))));
        team.addTeamMember(alice, "a", 0, 0, 12);

        // zero vesting months
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidParams()"))));
        team.addTeamMember(alice, "a", 100, 0, 0);
    }

    function testAddDuplicateReverts() public {
        _addMember(alice, "alice", 100 ether, 0, 12);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AlreadyExists()"))));
        team.addTeamMember(alice, "alice2", 50, 0, 6);
    }

    /* ========== CLAIM / VESTING ========== */

    function testClaimBeforeCliffReverts() public {
        _addMember(alice, "alice", 1200 ether, 2, 12);
        // fast forward less than cliff
        vm.warp(block.timestamp + (1 * SECONDS_PER_MONTH));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NoClaimable()"))));
        team.claim();
    }

    function testPartialVestingAfterOneMonth() public {
        uint256 allocation = 1200 ether;
        _addMember(alice, "alice", allocation, 0, 12);
        _fundContract(allocation);

        vm.warp(block.timestamp + (1 * SECONDS_PER_MONTH));

        uint256 expectedVested = (allocation * 1) / 12;

        vm.prank(alice);
        team.claim();

        (, , , uint256 remaining, , , , uint256 withdrawn, , uint256 claimable) = team.getMember(alice);
        assertEq(withdrawn, expectedVested);
        assertEq(remaining, allocation - expectedVested);
        assertEq(claimable, 0);
    }

    function testFullVestingAfterDuration() public {
        uint256 allocation = 500 ether;
        uint256 cliff = 1;
        uint256 vest = 6;
        _addMember(bob, "bob", allocation, cliff, vest);

        _fundContract(allocation);

        vm.warp(block.timestamp + (cliff + vest) * SECONDS_PER_MONTH + 1 days);

        vm.prank(bob);
        team.claim();

        (, , , uint256 remaining, , , , uint256 withdrawn, bool isActive, uint256 claimable) = team.getMember(bob);
        assertEq(withdrawn, allocation);
        assertEq(remaining, 0);
        assertFalse(isActive);
        assertEq(claimable, 0);
    }

    function testClaimInsufficientContractBalanceReverts() public {
        uint256 allocation = 1_000 ether;
        _addMember(alice, "alice", allocation, 0, 12);
        vm.warp(block.timestamp + 1 * SECONDS_PER_MONTH);
        vm.prank(alice);
        vm.expectRevert(bytes("Not enough tokens in contract"));
        team.claim();
    }

    function testDeactivateMemberPreventsClaim() public {
        _addMember(alice, "alice", 100 ether, 0, 12);
        team.deactivateMember(alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotActive()"))));
        team.claim();
    }

    function testClaimPartialThenFull() public {
        uint256 allocation = 1000 ether;
        _addMember(alice, "alice", allocation, 0, 4);
        _fundContract(allocation);

        vm.warp(block.timestamp + SECONDS_PER_MONTH);
        vm.prank(alice);
        team.claim();
        (, , , uint256 remaining1, , , , uint256 withdrawn1, bool isActive1, ) = team.getMember(alice);

        assertEq(withdrawn1, (allocation * 1) / 4);
        assertEq(remaining1, allocation - withdrawn1);
        assertTrue(isActive1);

        vm.warp(block.timestamp + 3 * SECONDS_PER_MONTH + 1);
        vm.prank(alice);
        team.claim();
        (, , , uint256 remaining2, , , , uint256 withdrawn2, bool isActive2, ) = team.getMember(alice);
        assertEq(withdrawn2, allocation);
        assertEq(remaining2, 0);
        assertFalse(isActive2);
    }

    /* ========== ROUNDING BEHAVIOR ========== */

    function testVestingRoundingBehavior() public {
        uint256 allocation = 100;
        uint256 vestingMonths = 3;
        _addMember(bob, "bob", allocation, 0, vestingMonths);
        _fundContract(allocation);

        // vm.warp(block.timestamp + uint256(1 days) + (SECONDS_PER_MONTH * 1) + (SECONDS_PER_MONTH * 0)); // ensure >1 month but <2
        vm.warp(block.timestamp + 30 days);

        uint256 expectedVested = (allocation * 1) / vestingMonths;
        vm.prank(bob);
        team.claim();

        (, , , uint256 remaining, , , , uint256 withdrawn, , ) = team.getMember(bob);
        assertEq(withdrawn, expectedVested);
        assertEq(remaining, allocation - expectedVested);
    }

    /* ========== OWNER / RECOVER / ACCESS CONTROL / PAUSE ========== */

    function testRecoverERC20AsOwnerWorks() public {
        uint256 amount = 1000 ether;
        gmg.transfer(address(team), amount);
        team.recoverERC20(address(gmg), amount);
        assertEq(gmg.balanceOf(address(team)), 0);
        assertEq(gmg.balanceOf(ownerAddr), 1_000_000 ether - amount + amount);
    }

    function testRecoverERC20NonOwnerReverts() public {
        uint256 amount = 500 ether;
        gmg.transfer(address(team), amount);
        vm.prank(address(0xDEAD));
        vm.expectRevert(bytes("OwnableUnauthorizedAccount(0x000000000000000000000000000000000000dEaD)"));
        team.recoverERC20(address(gmg), amount);
    }

    function testPausePreventsAddMember() public {
        team.pause();
        vm.expectRevert(bytes("EnforcedPause()"));
        team.addTeamMember(alice, "alice", 100, 0, 12);
    }

    function testUnpauseAllowsAddMember() public {
        team.pause();
        team.unpause();
        _addMember(alice, "alice", 100, 0, 12);
        (, , uint256 allocation, , , , , , , ) = team.getMember(alice);
        assertEq(allocation, 100);
    }

    /* ========== NEGATIVE / NON-MEMBER ========== */

    function testNonMemberClaimReverts() public {
        vm.prank(address(0xC0FFEE));
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotMember()"))));
        team.claim();
    }

    function testGetMemberNonMemberReverts() public {
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("NotMember()"))));
        team.getMember(address(0xDEADBEEF));
    }

    /* ========== FUZZ: random allocation / months (bounded) ========== */

    function testFuzz_VestingProgress(uint256 allocation) public {

        vm.assume(allocation > 0.000001 ether && allocation < 1_000_000 ether);

        uint256 vestingMonths = 12;
        _addMember(alice, "alice", allocation, 0, vestingMonths);
        _fundContract(allocation);

        vm.warp(block.timestamp + 5 * SECONDS_PER_MONTH);

        uint256 expectedVested = (allocation * 5) / vestingMonths;
        vm.prank(alice);
        team.claim();

        (, , , uint256 remaining, , , , uint256 withdrawn, , ) = team.getMember(alice);
        assertEq(withdrawn, expectedVested);
        assertEq(remaining, allocation - expectedVested);
    }
}
