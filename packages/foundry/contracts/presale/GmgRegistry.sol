// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";


contract GMGRegistry is Ownable {

    mapping(address => uint256) private totalBoughtInUsd;
    mapping(address => bool) private authorizedPresale;

    error unauthorized_presale();

    modifier onlyAuthorizedPresale() {
        if(!authorizedPresale[msg.sender]) revert unauthorized_presale();
        _;
    }
    
    constructor() Ownable(msg.sender) {}
    
    function authorizePresaleContract(address _presaleContract) external onlyOwner {
        authorizedPresale[_presaleContract] = true;
    }

    function revokePresaleContract(address _presaleContract) external onlyOwner {
        authorizedPresale[_presaleContract] = false;
    }

    function updateTotalBought(address _participant, uint256 _amount) external onlyAuthorizedPresale {
        totalBoughtInUsd[_participant] += _amount;
    }

    function getTotalBought(address _participant) external view onlyAuthorizedPresale returns(uint256){
        return totalBoughtInUsd[_participant];
    }
}