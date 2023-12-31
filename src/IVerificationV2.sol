// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IVerificationV2 {
  error Expired();
  error Inactive();
  error AlreadyInGroup();
  error InvalidSignature();
  error DuplicateIdentityCommitment();

  event FeePaid(address indexed account);
  event SignerChanged(address indexed previousSigner, address indexed newSigner);
  event FeeTokenChanged(address indexed oldFeeToken, address indexed newFeeToken);
  event GroupChanged(uint256 newGroupId, uint256 depth);

  struct GroupDetails {
    uint256 id;
    uint256 depth;
    uint256 startTime;
  }

  function payFeeFor(address account) external;
}
