// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IVerificationV2 {
  error CredentialExpired();
  error IdHashInUse();
  error InvalidSignature();
  error NotVerified();

  event FeePaid(address indexed account);
  event VerificationUpdated(address indexed account, uint256 expiration);
  event SignerChanged(address indexed previousSigner, address indexed newSigner);
  event FeeChoicesChanged();

  struct FeeConfig {
    IERC20 token;
    uint amount;
  }

  struct VerifiedPassport {
    uint expiration;
    bytes32 countryAndDocNumberHash;
  }
}
