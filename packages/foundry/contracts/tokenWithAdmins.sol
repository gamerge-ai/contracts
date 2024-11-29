// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GamergeTokenAdmin is ERC20, ERC20Permit, ERC20Pausable, AccessControl {

    bytes32 public constant ADMIN = keccak256("ADD_AS_ADMIN");
    mapping(address => uint256) public votesToGrantAdmin;
    mapping(address => uint256) public votesToRevokeAdmin;
    mapping(address => bool) public blacklistedAdmin;
    uint8 private totalAdmins;
    uint8 private votesToBurn;
    address public burnerAddress;


    error OACGP(); // OACGP - only admins can grant permissions
    error AA(); // AA - already admin
    error OACRP(); // OACGP - only admins can revoke permissions
    error NATR(); // NATR - not an existing admin to revoke
    error CVY(); //CVY - cant vote yourself
    error BLA(); //BLA - blacklisted address

    event TokenCreated(address indexed tokenAddress, address indexed creator, string tokenName, string tokenSymbol, uint256 tokenTotalSupply, address burnerAddress);
    event TokensMinted(address indexed tokenAddress, address indexed mintedBy, uint256 amountedMinted);
    event TokensBurned(address indexed burnedFrom, uint256 amountBurned);
    event VoteGranted(address indexed voter, address indexed admin);
    event VoteRevoked(address indexed voter, address indexed admin);
    event NewAdminGranted(address indexed grantedAddress);
    event ExistingAdminRevoked(address indexed revokedAddress);

    struct TokenDetails {
        string tokenName;
        string tokenSymbol;
        uint256 tokenTotalSupply;
        address tokenAddress;
        address burnerAddress;
    }

    TokenDetails public tokenDetails;
    
    constructor( 
        string memory _name, 
        string memory _symbol, 
        uint256 _totalSupply, 
        address[] memory _owners,
        address _burnerAddress
    ) ERC20(_name, _symbol) ERC20Permit(_name){
        require(_burnerAddress != address(0), "cant be null address");
        grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(ADMIN, msg.sender);
        for(uint i=0; i< _owners.length; i++) {
            grantRole(ADMIN, _owners[i]);
        }
        burnerAddress = _burnerAddress;
        tokenDetails = TokenDetails({
            tokenName: _name,
            tokenSymbol: _symbol,
            tokenTotalSupply: _totalSupply,
            tokenAddress: address(this),
            burnerAddress: _burnerAddress
        });

        emit TokenCreated(address(this), msg.sender, _name, _symbol, _totalSupply, _burnerAddress);
        _mint(msg.sender, _totalSupply);
        emit TokensMinted(address(this), msg.sender, _totalSupply);
    }

    function finalGrantAdmin(address _admin) private {
        grantRole(ADMIN, _admin);
        totalAdmins += 1;
        votesToGrantAdmin[_admin] = 0;
        emit NewAdminGranted(_admin);
    }

    function voteToGrantAdminRole(address _admin) public onlyRole(ADMIN) {
        if(hasRole(ADMIN, _admin)) revert AA(); // AA - already admin
        if(blacklistedAdmin[_admin]) revert BLA(); //BLA - blacklisted address
        if(msg.sender == _admin) revert CVY(); //CVY - cant vote yourself
        votesToGrantAdmin[_admin] += 1;
        emit VoteGranted(msg.sender, _admin);
        if(votesToGrantAdmin[_admin] >= (2 * totalAdmins) / 3) {
            finalGrantAdmin(_admin);
        }
    }

    function finalRevokeAdmin(address _admin) private {
        revokeRole(ADMIN, _admin);
        blacklistedAdmin[_admin] = true;
        totalAdmins -= 1;
        emit ExistingAdminRevoked(_admin);
    }

    function voteToRevokeAdminRole(address _admin) public onlyRole(ADMIN) {
        if(!hasRole(ADMIN, _admin)) revert NATR(); // NATR - not an existing admin to revoke
        if(msg.sender == _admin) revert CVY(); //CVY - cant vote yourself
        votesToRevokeAdmin[_admin] += 1;
        emit VoteRevoked(msg.sender, _admin);
        if(votesToRevokeAdmin[_admin] >= (2 * totalAdmins) / 3) {
            finalRevokeAdmin(_admin);
        }
    }

    function voteToBurn(uint256 _amount) public onlyRole(ADMIN) {
        votesToBurn += 1;
        if(votesToBurn >= (2 * totalAdmins) / 3) {
            burn(burnerAddress, _amount);
            votesToBurn = 0;
        }
    }

    function burn(address _burnFrom, uint256 _amount) private {
        _burn(_burnFrom, _amount);
    }

    function pause() public onlyRole(ADMIN) {
        _pause();
    }

    function unpause() public onlyRole(ADMIN) {
        _unpause();
    }

    function retrieveTokenDetails() public view returns (TokenDetails memory) {
        return tokenDetails;
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, amount);
    }
}