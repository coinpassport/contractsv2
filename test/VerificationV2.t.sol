// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";

import "../src/VerificationV2.sol";

import "./DummyERC20.sol";
import "./MockSemaphore.sol";

contract VerificationV2Test is Test {
  VerificationV2 public main;
  address signer;
  uint256 signerPk;
  DummyERC20 public feeToken;
  MockSemaphore public semaphore;
  uint constant public feeAmount = 123;
  uint constant public groupId = 1234;

  function setUp() public {
    semaphore = new MockSemaphore();
    (signer, signerPk) = makeAddrAndKey('test_signer');
    feeToken = new DummyERC20("Test Token", "TEST");
    VerificationV2.FeeConfig[] memory feeChoices = new VerificationV2.FeeConfig[](1);
    feeChoices[0].token = IERC20(feeToken);
    feeChoices[0].amount = feeAmount;

    main = new VerificationV2(signer, address(semaphore), groupId, feeChoices);
  }

  function test_Verify() public {
    feeToken.mint(feeAmount);
    feeToken.approve(address(main), feeAmount);
    main.payFee(0);
    assertEq(main.feePaidBlock(address(this)), block.number);

    uint expiration = block.timestamp + 365 days;
    bytes32 countryAndDocNumberHash = keccak256('test123');
    uint idCommitment = 123456;

    bytes memory sig = makeSignature(keccak256(abi.encode(
      address(this),
      expiration,
      countryAndDocNumberHash
    )));

    main.publishVerification(expiration, countryAndDocNumberHash, idCommitment, sig);
    assertEq(main.feePaidBlock(address(this)), 0);
    assertTrue(semaphore.hasMember(groupId, idCommitment));

    uint256 signal = 123;
    uint256[8] memory proof = [uint256(0),0,0,0,0,0,0,0];
    bytes memory proofSig = makeSignature(keccak256(abi.encode(
      signal,
      proof
    )));
    main.submitProof(
      idCommitment, // mock takes idCommitment as merkleTreeRoot
      signal,
      proofSig,
      0, // nullifierHash
      0, // externalNullifier
      proof
    );

    // The mock doesn't check these values
    uint256[] memory proofSiblings = new uint256[](0);
    uint8[] memory proofPathIndices = new uint8[](0);

    main.revokeVerification(proofSiblings, proofPathIndices);
    assertTrue(!semaphore.hasMember(groupId, idCommitment));

  }

  function makeSignature(bytes32 hash) internal view returns(bytes memory) {
    bytes32 ethSignedHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethSignedHash);
    return abi.encodePacked(r, s, v);
  }

}
