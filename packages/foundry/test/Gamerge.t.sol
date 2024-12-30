// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/Gamerge.sol";

contract GamergeTest is Test {
  address owner = makeAddr("owner");
  Gamerge public gamerge;

  function setUp() public {
    vm.prank(owner);
    gamerge = new Gamerge();
  }

  function testUpdatingSymbol() public {
    string memory before = gamerge.symbol();

    vm.prank(owner);
    gamerge.setSymbol("MGM");

    assertEq(gamerge.symbol(), "MGM");
  }
}
