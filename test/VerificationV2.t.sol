// SPDX-License-Identifier: MIT
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
  uint constant public groupId = 1234;

  function setUp() public {
    semaphore = new MockSemaphore();
    (signer, signerPk) = makeAddrAndKey('test_signer');
    feeToken = new DummyERC20("Test Token", "TEST");

    main = new VerificationV2(
      "Coinpassport V2",
      "CPV2",
      signer,
      address(semaphore),
      address(feeToken),
      groupId,
      16 // doesn't matter, not used
    );
  }

  function test_Verify() public {
    feeToken.mint(1);
    feeToken.approve(address(main), 1);
    main.payFee();
    assertEq(main.feePaidBlock(address(this)), block.number);
    assertEq(feeToken.balanceOf(address(this)), 0);

    bytes32 idHash = keccak256('test123');
    uint idCommitment = 123456;
    uint expiration = block.timestamp + 2 weeks;

    bytes memory sig = makeSignature(keccak256(abi.encode(
      address(this),
      expiration,
      idHash
    )));

    main.publishVerification(
      expiration,
      idHash,
      idCommitment,
      sig
    );
    assertEq(main.feePaidBlock(address(this)), 0);
    assertTrue(semaphore.hasMember(groupId, idCommitment));

    address anon = address(2);
    uint256[8] memory proof = [uint256(0),0,0,0,0,0,0,0];
    vm.prank(anon);
    main.submitProof(
      idCommitment, // mock takes idCommitment as merkleTreeRoot
      0, // signal
      0, // nullifierHash
      0, // externalNullifier
      proof
    );

    assertEq(main.balanceOf(anon), 1);
    assertTrue(main.addressActive(anon));

    main.newGroup(groupId + 1, 16, block.timestamp + 1 days);
    // Make another one further in the further too that won't activate
    main.newGroup(groupId + 2, 16, block.timestamp + 4 weeks);
    // Still active for another day
    assertTrue(main.addressActive(anon));

    vm.warp(block.timestamp + 2 days);
    assertTrue(!main.addressActive(anon));

    vm.warp(block.timestamp + 5 days);

    vm.prank(anon);
    vm.expectRevert();
    main.submitProof(idCommitment, 0, 0, 0, proof);

    main.joinNewGroup(idCommitment + 1);

    vm.prank(anon);
    main.submitProof(idCommitment + 1, 0, 0, 0, proof);

    vm.warp(block.timestamp + 2 weeks);

    vm.expectRevert();
    main.joinNewGroup(idCommitment + 2);
    vm.expectRevert();
    main.submitProof(idCommitment + 2, 0, 0, 0, proof);

    // Submit a new id with a future expiration
    expiration = block.timestamp + 2 weeks;
    idHash = keccak256('newidhash123');
    sig = makeSignature(keccak256(abi.encode(
      address(this),
      expiration,
      idHash
    )));

    main.publishVerification(
      expiration,
      idHash,
      idCommitment + 2,
      sig
    );

    vm.prank(anon);
    main.submitProof(idCommitment + 2, 0, 0, 0, proof);
  }

  function test_ChangeIdAccount() public {
    bytes32 idHash = keccak256('test123');
    uint idCommitment = 123456;
    uint expiration = block.timestamp + 2 weeks;

    bytes memory sig = makeSignature(keccak256(abi.encode(
      address(this),
      expiration,
      idHash
    )));

    main.publishVerification(
      expiration,
      idHash,
      idCommitment,
      sig
    );

    assertTrue(main.idHashInGroup(idHash, groupId));

    address other = address(3);
    sig = makeSignature(keccak256(abi.encode(
      other,
      expiration,
      idHash
    )));

    vm.prank(other);
    main.publishVerification(
      expiration,
      idHash,
      idCommitment + 1,
      sig
    );

    address anon = address(2);
    uint256[8] memory proof = [uint256(0),0,0,0,0,0,0,0];
    vm.prank(anon);
    vm.expectRevert();
    main.submitProof(
      idCommitment + 1, // cannot join group using new account
      0, // signal
      0, // nullifierHash
      0, // externalNullifier
      proof
    );

    main.newGroup(groupId + 1, 16, block.timestamp + 1 days);
    vm.warp(block.timestamp + 2 days);

    vm.expectRevert();
    // Original id holding account cannot join this group
    main.joinNewGroup(idCommitment + 2);

    vm.prank(other);
    // Only the new holder
    main.joinNewGroup(idCommitment + 2);

    vm.prank(anon);
    main.submitProof(
      idCommitment + 2,
      0, // signal
      0, // nullifierHash
      0, // externalNullifier
      proof
    );
  }

  function makeSignature(bytes32 hash) internal view returns(bytes memory) {
    bytes32 ethSignedHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethSignedHash);
    return abi.encodePacked(r, s, v);
  }

}
