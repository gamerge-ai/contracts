// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GamergeToken is ERC20, ERC20Permit, Ownable {

    struct TokenDetails {
        string tokenName;
        string tokenSymbol;
        uint256 tokenTotalSupply;
        address tokenAddress;
        address burnerAddress;
    }

    constructor( 
        string memory _name, 
        string memory _symbol, 
        uint256 _totalSupply, 
        address _burnerAddress
    ) ERC20(_name, _symbol) ERC20Permit(_name){
        require(_burnerAddress != address(0), "cant be null address");
        burnerAddress = _burnerAddress;
        tokenDetails = TokenDetails({
            tokenName: _name,
            tokenSymbol: _symbol,
            tokenTotalSupply: _totalSupply,
            tokenAddress: address(this),
            burnerAddress: _burnerAddress
        });
    }

}