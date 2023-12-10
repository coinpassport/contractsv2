// SPDX-License-Identifier: MIT
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
    address feeToken = vm.envAddress("FEE_TOKEN");
    uint groupId = vm.envUint("GROUP_ID");
    uint groupDepth = vm.envUint("GROUP_DEPTH");
    new VerificationV2(
      "Coinpassport",
      "PASSPORT",
      signer,
      semaphore,
      feeToken,
      groupId,
      groupDepth
    );

    vm.stopBroadcast();
  }
}
