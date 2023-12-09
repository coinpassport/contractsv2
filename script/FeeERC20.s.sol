// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import "../src/FeeERC20.sol";

contract Deploy is Script {
  function setUp() public {}

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address collector = vm.envAddress("COLLECTOR");
    address payToken = vm.envAddress("PAY_TOKEN");
    uint payAmount = vm.envUint("PAY_AMOUNT");
    address feeRecipient = vm.envAddress("FEE_RECIPIENT");

    FeeERC20.FeeConfig[] memory feeChoices = new FeeERC20.FeeConfig[](1);
    feeChoices[0].token = IERC20(payToken);
    feeChoices[0].amount = payAmount;

    new FeeERC20(
      "Coinpassport Fee Token",
      "CPFEE",
      feeChoices,
      feeRecipient,
      collector
    );

    vm.stopBroadcast();
  }
}

