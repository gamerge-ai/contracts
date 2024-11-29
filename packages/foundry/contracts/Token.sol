// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GamergeToken is ERC20, ERC20Permit, ERC20Capped, Ownable {

    struct TokenDetails {
        string tokenName;
        string tokenSymbol;
        uint256 tokenTotalSupply;
        address tokenAddress;
        address burnerAddress;
    }

    address public burnerAddress;
    TokenDetails public tokenDetails;
    uint8 public constant DECIMALS = 18;

    constructor( 
        string memory _name, 
        string memory _symbol, 
        uint256 _totalSupply, 
        uint256 _cap,
        address _burnerAddress
    ) ERC20(_name, _symbol) ERC20Permit(_name) ERC20Capped(_cap * 10 ** decimals()) Ownable(msg.sender){
        require(_burnerAddress != address(0), "cant be null address");
        burnerAddress = _burnerAddress;
        tokenDetails = TokenDetails({
            tokenName: _name,
            tokenSymbol: _symbol,
            tokenTotalSupply: _totalSupply * 10 ** decimals(),
            tokenAddress: address(this),
            burnerAddress: _burnerAddress
        });
        _mint(msg.sender, tokenDetails.tokenTotalSupply);
    }

    function burn(uint256 _amount) public onlyOwner {
        uint256 amount_to_burn = _amount * 10 ** 18;
        _burn(burnerAddress, amount_to_burn);
    }

    function retrieveTokenDetails() public view returns(TokenDetails memory) {
        return tokenDetails;
    } 

    function decimals() public pure override returns(uint8) {
        return DECIMALS;
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Capped) {
        super._update(from, to, amount);
    }

}