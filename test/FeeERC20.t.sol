// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";

import "../src/FeeERC20.sol";

import "./DummyERC20.sol";

contract FeeERC20Test is Test {
  DummyERC20 public dummyToken;
  FeeERC20 public feeToken;

  uint constant public dummyAmount = 15;
  address constant public feeRecipient = address(3);

  function setUp() public {
    dummyToken = new DummyERC20("Dummy", "DUMMY");

    FeeERC20.FeeConfig[] memory feeChoices = new FeeERC20.FeeConfig[](1);
    feeChoices[0].token = IERC20(dummyToken);
    feeChoices[0].amount = dummyAmount;
    feeToken = new FeeERC20("Fee", "FEE", feeChoices, feeRecipient, address(1));
  }

  function test_BuyOne() public {
    dummyToken.mint(dummyAmount);
    dummyToken.approve(address(feeToken), dummyAmount);
    feeToken.mint(0, 1);
    assertEq(feeToken.balanceOf(address(this)), 1);
    assertEq(dummyToken.balanceOf(address(this)), 0);
    assertEq(dummyToken.balanceOf(feeRecipient), dummyAmount);

    vm.expectRevert();
    feeToken.transferFrom(address(this), address(1), 1);

    feeToken.setCollector(address(this));
    feeToken.transferFrom(address(this), address(1), 1);
    assertEq(feeToken.balanceOf(address(this)), 0);
    assertEq(feeToken.balanceOf(address(1)), 1);
  }
}
