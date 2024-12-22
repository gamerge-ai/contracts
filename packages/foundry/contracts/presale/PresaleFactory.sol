// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Presale} from "./Presale.sol";

//@audit why inherited the ownable instead of ownable2step?
// and how about PresaleFactory for the name instead?
contract PresaleFactory is Ownable {

    mapping(address => uint256) private totalBoughtInUsd;
    mapping(address => bool) public authorizedPresale;

    event newPresaleCreated(address indexed presaleAddress);

    error unauthorized_presale();

    // modifier onlyAuthorizedPresale() {
    //     if(!authorizedPresale[msg.sender]) revert unauthorized_presale();
    //     _;
    // }
    
    constructor() Ownable(msg.sender) {
    }

    function initiatePresale(
        uint16 _tokenPrice,
        uint88 _tokenAllocation,
        uint24 _cliff,
        uint8 _vestingMonths,
        uint8 _tgePercentages,
        address _bnbPriceAggregator, 
        address _gmgAddress, 
        address _usdtAddress
    ) public onlyOwner returns(address){
        Presale newPresale = new Presale(_tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages, _bnbPriceAggregator, _gmgAddress, _usdtAddress, address(this));
        authorizedPresale[address(newPresale)] = true;
        emit newPresaleCreated(address(newPresale));
        return address(newPresale);
    }
    
    // //@audit there should be an onlyOwner function to deploy the Presale contract
    // function authorizePresaleContract(address _presaleContract) private onlyOwner {
    //     authorizedPresale[_presaleContract] = true;
    // }

    function revokePresaleContract(address _presaleContract) external onlyOwner {
        authorizedPresale[_presaleContract] = false;
    }

    function updateTotalBought(address _participant, uint256 _amount) external {
        if(!authorizedPresale[msg.sender]) revert unauthorized_presale();
        totalBoughtInUsd[_participant] += _amount;
    }

    //@audit no need to access restrict view functions
    function getTotalBought(address _participant) external view returns(uint256){
        return totalBoughtInUsd[_participant];
    }

}