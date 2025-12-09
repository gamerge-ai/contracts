// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Team Vesting Contract
/// @notice Owner can add team members with an allocation, cliff (months) and vesting (months).
/// Owner funds contract separately. Members can claim vested tokens if contract has balance.
contract TeamContract is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable gmgToken;
    uint256 private constant SECONDS_PER_MONTH = 30 days;

    struct TeamMember {
        address memberAddr;
        string name;
        uint256 allocation;
        uint256 remaining;
        uint256 cliffMonths;
        uint256 vestingMonths;
        uint256 startTimestamp;
        uint256 withdrawn;
        bool isActive;
    }

    mapping(address => TeamMember) public members;
    mapping(address => bool) public exists;

    // EVENTS
    event MemberAdded(address indexed member, string name, uint256 allocation, uint256 cliffMonths, uint256 vestingMonths);
    event MemberDeactivated(address indexed member);
    event Claimed(address indexed member, uint256 amount);
    event TokensRecovered(address indexed to, uint256 amount);

    // ERRORS
    error InvalidAddress();
    error AlreadyExists();
    error NotMember();
    error NotActive();
    error InvalidParams();
    error NoClaimable();

    constructor(address _gmgToken, address initialOwner) Ownable(initialOwner) {
        if (_gmgToken == address(0)) revert InvalidAddress();
        gmgToken = IERC20(_gmgToken);
    }

    /* ========== OWNER ACTIONS ========== */

    function addTeamMember(
        address _member,
        string calldata _name,
        uint256 _allocation,
        uint256 _cliffMonths,
        uint256 _vestingMonths
    ) public onlyOwner whenNotPaused {
        if (_member == address(0)) revert InvalidAddress();
        if (_allocation == 0 || _vestingMonths == 0) revert InvalidParams();
        if (exists[_member]) revert AlreadyExists();

        TeamMember memory tm = TeamMember({
            memberAddr: _member,
            name: _name,
            allocation: _allocation,
            remaining: _allocation,
            cliffMonths: _cliffMonths,
            vestingMonths: _vestingMonths,
            startTimestamp: block.timestamp,
            withdrawn: 0,
            isActive: true
        });

        members[_member] = tm;
        exists[_member] = true;

        emit MemberAdded(_member, _name, _allocation, _cliffMonths, _vestingMonths);
    }

    function deactivateMember(address _member) external onlyOwner whenNotPaused {
        if (!exists[_member]) revert NotMember();
        TeamMember storage tm = members[_member];
        tm.isActive = false;
        emit MemberDeactivated(_member);
    }

    /// @notice Recover any ERC20 sent to this contract (e.g. wrong token)
    function recoverERC20(address token, uint256 amount) public onlyOwner nonReentrant {
        if (token == address(0)) revert InvalidAddress();
        IERC20(token).safeTransfer(owner(), amount);
        emit TokensRecovered(owner(), amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* ========== MEMBER ACTIONS ========== */

    function claim() public nonReentrant whenNotPaused {
        address caller = msg.sender;
        if (!exists[caller]) revert NotMember();
        TeamMember storage tm = members[caller];
        if (!tm.isActive) revert NotActive();

        uint256 claimable = claimableAmount(caller);
        if (claimable == 0) revert NoClaimable();

        if (claimable > tm.remaining) {
            claimable = tm.remaining;
        }

        uint256 bal = gmgToken.balanceOf(address(this));
        require(bal >= claimable, "Not enough tokens in contract");

        tm.withdrawn += claimable;
        tm.remaining -= claimable;

        if (tm.remaining == 0) {
            tm.isActive = false;
        }

        gmgToken.safeTransfer(caller, claimable);
        emit Claimed(caller, claimable);
    }

    function claimableAmount(address _member) public view returns (uint256) {
        if (!exists[_member]) revert NotMember();
        TeamMember storage tm = members[_member];
        uint256 vested = _vestedAmount(tm);
        if (vested <= tm.withdrawn) return 0;
        return vested - tm.withdrawn;
    }

    function vestedAmount(address _member) public view returns (uint256) {
        if (!exists[_member]) revert NotMember();
        TeamMember storage tm = members[_member];
        return _vestedAmount(tm);
    }

    /* ========== INTERNAL ========== */

    function _vestedAmount(TeamMember storage tm) internal view returns (uint256) {
        if (tm.vestingMonths == 0) return 0;

        uint256 cliffEnd = tm.startTimestamp + (tm.cliffMonths * SECONDS_PER_MONTH);
        if (block.timestamp < cliffEnd) {
            return 0;
        }

        uint256 elapsed = block.timestamp - cliffEnd;
        uint256 monthsElapsed = elapsed / SECONDS_PER_MONTH;

        if (monthsElapsed >= tm.vestingMonths) {
            return tm.allocation;
        }

        return (tm.allocation * monthsElapsed) / tm.vestingMonths;
    }

    /* ========== GETTERS ========== */

    function getMember(address _member) external view returns (
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
    ) {
        if (!exists[_member]) revert NotMember();
        TeamMember storage tm = members[_member];
        memberAddr = tm.memberAddr;
        name = tm.name;
        allocation = tm.allocation;
        remaining = tm.remaining;
        cliffMonths = tm.cliffMonths;
        vestingMonths = tm.vestingMonths;
        startTimestamp = tm.startTimestamp;
        withdrawn = tm.withdrawn;
        isActive = tm.isActive;
        claimable = claimableAmount(_member);
    }

    function isPaused() external view returns (bool) {
        return paused();
    }
}
