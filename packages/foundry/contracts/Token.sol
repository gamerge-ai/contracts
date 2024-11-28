// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GamergeToken is ERC20, ERC20Permit, AccessControl {

    bytes32 public constant ADMIN = keccak256("ADD_AS_ADMIN");
    mapping(address => uint256) public votesToGrantAdmin;
    mapping(address => uint256) public votesToRevokeAdmin;
    uint8 private totalAdmins;


    error OACGP(); // OACGP - only admins can grant permissions
    error AA(); // AA - already admin
    error OACRP(); // OACGP - only admins can revoke permissions;
    error NATR(); // NATR - not an existing admin to revoke

    event TokenCreated(address indexed tokenAddress, address indexed creator, string tokenName, string tokenSymbol, uint256 tokenTotalSupply);
    event TokensBurned(address indexed burnedFrom, uint256 amountBurned);
    event NewAdminGranted(address indexed grantedAddress, address addedBy);
    event ExistingAdminRevoked(address indexed revokedAddress, address revokedBy);
    event TokensMinted(address indexed tokenAddress, address indexed mintedBy, uint256 amountedMinted);
    
    constructor( 
        string memory _name, 
        string memory _symbol, 
        uint256 _totalSupply, 
        address[] memory _owners
    ) ERC20(_name, _symbol) ERC20Permit(_name){
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(ADMIN, msg.sender);
        for(uint i=0; i< _owners.length; i++) {
            grantRole(ADMIN, _owners[i]);

        }
        emit TokenCreated(address(this), msg.sender, _name, _symbol, _totalSupply);
        _mint(msg.sender, _totalSupply);
        emit TokensMinted(address(this), msg.sender, _totalSupply);
    }

    function voteToGrantAdminRole(address _admin) public onlyRole(ADMIN) {
        if(!hasRole(ADMIN, msg.sender)) revert OACGP(); // OACGP - only admins can grant permissions;
        if(hasRole(ADMIN, _admin)) revert AA(); // AA - already admin
        if(votesToGrantAdmin[_admin] >= (2 * totalAdmins) / 3) {
            grantRole(ADMIN, _admin);
            totalAdmins += 1;
        }
    }

    function voteToRevokeAdminRole(address _admin) public onlyRole(ADMIN) {
        if(!hasRole(ADMIN, _admin)) revert NATR(); // NATR - not an existing admin to revoke
        if(!hasRole(ADMIN, msg.sender)) revert OACRP(); // OACGP - only admins can revoke permissions;
        if(votesToRevokeAdmin[_admin] >= (2 * totalAdmins) / 3) {
            revokeRole(ADMIN, _admin);
            totalAdmins -= 1;
        }
    }

    function burn(address _burnFrom, uint256 _amount) public onlyRole(ADMIN) {
        _burn(_burnFrom, _amount);
    }

    function tokenName() public view returns(string memory) {
        return name();
    }

    function tokenSymbol() public view returns(string memory) {
        return symbol();
    }

    function tokenTotalSupply() public view returns(uint256) {
        return totalSupply();
    }

    // function finalGrantAdminRole(address _admin) private {
    //     grantRole(ADMIN, _admin);
    //     totalAdmins += 1;
    // }

    // function finalRevokeAdminRole(address _admin) private {
    //     revokeRole(ADMIN, _admin);
    //     totalAdmins -= 1;
    // }
}