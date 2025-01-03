// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC1967Proxy } from
  "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
  Ownable2Step,
  Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from
  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPresale.sol";
import "./interfaces/IVesting.sol";

contract PresaleFactory is Ownable2Step {
  using SafeERC20 for IERC20;

  IPresale private presaleImpl;
  IVesting public vestingImpl;

  address public bnb_pa;
  address public gmg;
  address public immutable USDT;

  mapping(address => uint256) private _totalBoughtInUsd;

  mapping(IPresale => bool) public validPresale;
  IPresale[] private _presales;

  event NewPresaleCreated(IPresale indexed presaleAddress);

  error zero_address();
  error unauthorized_presale();

  constructor(
    IPresale _pre,
    IVesting _vest,
    address _bnbPA,
    address _gmg,
    address _usdt
  ) Ownable(msg.sender) {
    presaleImpl = _pre;
    vestingImpl = _vest;

    bnb_pa = _bnbPA;
    gmg = _gmg;
    USDT = _usdt;
  }

  function createPresale(
    uint256 _tokenPrice,
    uint256 _tokenAllocation,
    uint64 _cliff,
    uint8 _vestingMonths,
    uint8 _tgePercentages,
    uint8 _presaleStage
  ) public onlyOwner returns (address) {
    IPresale.InitParams memory params = IPresale.InitParams({
      tokenPrice: _tokenPrice,
      tokenAllocation: _tokenAllocation,
      cliff: _cliff,
      vestingMonths: _vestingMonths,
      tgePercentages: _tgePercentages,
      presaleStage: _presaleStage,
      bnbPriceAggregator: bnb_pa,
      gmgAddress: gmg,
      usdtAddress: USDT,
      presaleFactory: address(this),
      owner: msg.sender
    });

    IPresale newPresale = IPresale(
      address(
        new ERC1967Proxy(
          address(presaleImpl), abi.encodeCall(IPresale.initialize, (params))
        )
      )
    );

    IERC20(gmg).safeTransferFrom(
      msg.sender, address(newPresale), _tokenAllocation
    );

    validPresale[newPresale] = true;
    _presales.push(newPresale);

    emit NewPresaleCreated(newPresale);
    return address(newPresale);
  }

  function updateBNB_PA(
    address _newBnbPA
  ) external onlyOwner {
    if (_newBnbPA == address(0)) revert zero_address();
    bnb_pa = _newBnbPA;
  }

  function updateGMG(
    address _newGMG
  ) external onlyOwner {
    if (_newGMG == address(0)) revert zero_address();
    gmg = _newGMG;
  }

  function updatePresaleImpl(
    address _newPresale
  ) external onlyOwner {
    if (_newPresale == address(0)) revert zero_address();
    presaleImpl = IPresale(_newPresale);
  }

  function updateVestingImpl(
    address _newVest
  ) external onlyOwner {
    if (_newVest == address(0)) revert zero_address();
    vestingImpl = IVesting(_newVest);
  }

  function startAllPresales() external onlyOwner {
    for (uint8 i = 0; i < _presales.length; i++) {
      IPresale p = _presales[i];

      if (!p.isPresaleStarted()) {
        p.startPresale();
      }
    }
  }

  function stopAllPresales() external onlyOwner {
    for (uint8 i = 0; i < _presales.length; i++) {
      IPresale p = _presales[i];

      if (p.isPresaleStarted()) {
        p.stopPresale();
      }
    }
  }

  function triggerTgeOnAllPresales() external onlyOwner {
    for (uint8 i = 0; i < _presales.length; i++) {
      IPresale p = _presales[i];

      if (!p.isTgeTriggered()) {
        p.triggerTGE();
      }
    }
  }

  function updateTotalBought(address _participant, uint256 _amount) external {
    if (!validPresale[IPresale(msg.sender)]) revert unauthorized_presale();

    _totalBoughtInUsd[_participant] += _amount;
  }

  function getTotalBought(
    address _participant
  ) external view returns (uint256 totalBought) {
    totalBought = _totalBoughtInUsd[_participant];
  }

  function getAllPresales() external view returns (IPresale[] memory) {
    return _presales;
  }
}
