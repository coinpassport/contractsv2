// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IVerificationV2 {
  error IdHashInUse();
  error InvalidSignature();

  event FeePaid(address indexed account);
  event SignerChanged(address indexed previousSigner, address indexed newSigner);
  event FeeTokenChanged(address indexed oldFeeToken, address indexed newFeeToken);
}
