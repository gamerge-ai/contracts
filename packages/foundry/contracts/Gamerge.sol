// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from
  "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from
  "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {
  Ownable2Step,
  Ownable
} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract Gamerge is ERC20, ERC20Burnable, ERC20Permit, Ownable2Step {
  event SymbolUpdated(string indexed newSymbol);

  string private _symbol;
  uint256 public constant CAP = 100_000_000 * 1e18; // 100 million;

  constructor()
    ERC20("Gamerge", "GMG")
    ERC20Permit("Gamerge")
    Ownable(msg.sender)
  {
    _symbol = "GMG";
    _mint(msg.sender, CAP);
  }

  function setSymbol(
    string calldata _newSymbol
  ) external onlyOwner {
    _symbol = _newSymbol;

    emit SymbolUpdated(_newSymbol);
  }

  function symbol() public view override returns (string memory) {
    return _symbol;
  }
}
