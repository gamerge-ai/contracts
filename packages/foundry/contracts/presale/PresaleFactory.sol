// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IPresale.sol";

contract PresaleFactory is Ownable2Step {

    IPresale private immutable PRESALE_IMPL;
    address public BNB_PA;
    address public GMG;
    address public immutable USDT;

    mapping(address => uint256) private _totalBoughtInUsd;
    mapping(IPresale => bool) public validPresale;

    event NewPresaleCreated(IPresale indexed presaleAddress);

    error unauthorized_presale();

    constructor(IPresale _pre, address _bnbPA, address _gmg, address _usdt) Ownable(msg.sender) {
        PRESALE_IMPL = _pre;

        BNB_PA = _bnbPA;
        GMG = _gmg;
        USDT = _usdt;
    }

    function initiatePresale(
        uint16 _tokenPrice,
        uint88 _tokenAllocation,
        uint24 _cliff,
        uint8 _vestingMonths,
        uint8 _tgePercentages
    ) public onlyOwner {
        IPresale newPresale = IPresale(Clones.clone(address(PRESALE_IMPL)));
        newPresale.initialize(_tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages, 0, BNB_PA, GMG, USDT, address(this), msg.sender);
        require(IERC20(GMG).transferFrom(msg.sender, address(newPresale), _tokenAllocation), "GMG transfer to presale failed");

        validPresale[newPresale] = true;

        emit NewPresaleCreated(newPresale);
    }

    function updateBNB_PA(address _newBnbPA) external onlyOwner {
        BNB_PA = _newBnbPA;
    }

    function updateGMG(address _newGMG) external onlyOwner {
        GMG = _newGMG;
    }

    function updateTotalBought(address _participant, uint256 _amount) external {
        if(!validPresale[IPresale(msg.sender)]) revert unauthorized_presale();

        _totalBoughtInUsd[_participant] += _amount;
    }

    function getTotalBought(address _participant) external view returns(uint256 totalBought) {
        totalBought = _totalBoughtInUsd[_participant];
    }
}
