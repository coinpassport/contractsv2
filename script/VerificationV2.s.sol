// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import "../src/VerificationV2.sol";

contract Deploy is Script {
  function setUp() public {}

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(deployerPrivateKey);

    address signer = vm.envAddress("SIGNER");
    address semaphore = vm.envAddress("SEMAPHORE");
    uint groupId = vm.envUint("GROUP_ID");
    address feeToken = vm.envAddress("FEE_TOKEN");
    address feeRecipient = vm.envAddress("FEE_RECIPIENT");
    uint beginningOfTime = vm.envUint("BEGINNING_OF_TIME");
    new VerificationV2(
      "Coinpassport",
      "PASSPORT",
      signer,
      semaphore,
      groupId,
      feeToken,
      feeRecipient,
      beginningOfTime
    );

    vm.stopBroadcast();
  }
}
