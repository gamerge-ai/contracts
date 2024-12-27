// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


import "./IPresale.sol";

contract PresaleFactory is Ownable2Step {
    using SafeERC20 for IERC20;

    IPresale private immutable PRESALE_IMPL;
    address public BNB_PA;
    address public GMG;
    address public immutable USDT;

    mapping(address => uint256) private _totalBoughtInUsd;
    
    mapping(IPresale => bool) public validPresale;
    IPresale[] private _presales;

    event NewPresaleCreated(IPresale indexed presaleAddress);
    
    error zero_address();
    error unauthorized_presale();

    constructor(IPresale _pre, address _bnbPA, address _gmg, address _usdt) Ownable(msg.sender) {
        PRESALE_IMPL = _pre;

        BNB_PA = _bnbPA;
        GMG = _gmg;
        USDT = _usdt;
    }

    function createPresale(
        uint16 _tokenPrice,
        uint88 _tokenAllocation,
        uint24 _cliff,
        uint8 _vestingMonths,
        uint8 _tgePercentages,
        uint8 _presaleStage
    ) public onlyOwner {
        IPresale newPresale = IPresale(Clones.clone(address(PRESALE_IMPL)));
        newPresale.initialize(_tokenPrice, _tokenAllocation, _cliff, _vestingMonths, _tgePercentages, _presaleStage, BNB_PA, GMG, USDT, address(this), msg.sender);
        IERC20(GMG).safeTransferFrom(msg.sender, address(newPresale), _tokenAllocation);

        validPresale[newPresale] = true;
        _presales.push(newPresale);

        emit NewPresaleCreated(newPresale);
    }

    function updateBNB_PA(address _newBnbPA) external onlyOwner {
        if(_newBnbPA == address(0)) revert zero_address();
        BNB_PA = _newBnbPA;
    }

    function updateGMG(address _newGMG) external onlyOwner {
        if(_newGMG == address(0)) revert zero_address();
        GMG = _newGMG;
    }

    function startAllPresales() external onlyOwner {
        for(uint8 i = 0; i < _presales.length; i++) {
            IPresale p = _presales[i];

            if (!p.isPresaleStarted())
                p.startPresale();
        }
    }

    function stopAllPresales() external onlyOwner {
        for(uint8 i = 0; i < _presales.length; i++) {
            IPresale p = _presales[i];

            if (p.isPresaleStarted())
                p.stopPresale();
        }
    }

    function triggerTgeOnAllPresales() external onlyOwner {
        for(uint8 i = 0; i < _presales.length; i++) {
            IPresale p = _presales[i];

            if (!p.isTgeTriggered())
                p.triggerTGE();
        }
    }

    function updateTotalBought(address _participant, uint256 _amount) external {
        if(!validPresale[IPresale(msg.sender)]) revert unauthorized_presale();

        _totalBoughtInUsd[_participant] += _amount;
    }

    function getTotalBought(address _participant) external view returns(uint256 totalBought) {
        totalBought = _totalBoughtInUsd[_participant];
    }

    function getAllPresales() external view returns(IPresale[] memory) {
        return _presales;
    }
}
