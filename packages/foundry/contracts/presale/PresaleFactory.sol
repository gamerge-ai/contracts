// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Presale} from "./Presale.sol";

contract PresaleFactory is Ownable2Step {

    mapping(address => uint256) private totalBoughtInUsd;
    mapping(address => bool) public authorizedPresale;

    event NewPresaleCreated(address indexed presaleAddress);

    error unauthorized_presale();

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
        Presale newPresale = new Presale(_tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages, _bnbPriceAggregator, _gmgAddress, _usdtAddress, address(this), msg.sender);
        authorizedPresale[address(newPresale)] = true;
        emit NewPresaleCreated(address(newPresale));
        return address(newPresale);
    }

    function updateTotalBought(address _participant, uint256 _amount) external {
        if(!authorizedPresale[msg.sender]) revert unauthorized_presale();
        totalBoughtInUsd[_participant] += _amount;
    }

    function getTotalBought(address _participant) external view returns(uint256){
        return totalBoughtInUsd[_participant];
    }

}