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
  uint constant beginningOfTime = 1;
  address constant feeRecipient = address(100);

  function setUp() public {
    semaphore = new MockSemaphore();
    (signer, signerPk) = makeAddrAndKey('test_signer');
    feeToken = new DummyERC20("Test Token", "TEST");

    main = new VerificationV2(
      "Coinpassport V2",
      "CPV2",
      signer,
      address(semaphore),
      groupId,
      address(feeToken),
      feeRecipient,
      beginningOfTime
    );
  }

  function test_Verify() public {
    feeToken.mint(1);
    feeToken.approve(address(main), 1);
    main.payFee();
    assertEq(main.feePaidBlock(address(this)), block.number);
    assertEq(feeToken.balanceOf(feeRecipient), 1);

    bytes32 idHash = keccak256('test123');
    uint idCommitment = 123456;

    bytes memory sig = makeSignature(keccak256(abi.encode(
      address(this),
      idHash
    )));

    main.publishVerification(idHash, idCommitment, sig);
    assertEq(main.feePaidBlock(address(this)), 0);
    assertTrue(semaphore.hasMember(groupId, idCommitment));

    address anon = address(2);

    uint timePassed = (block.timestamp - beginningOfTime) / 4 weeks;
    // 2 months active after now
    uint256 signal = timePassed + 2;
    uint256[8] memory proof = [uint256(0),0,0,0,0,0,0,0];
    bytes memory proofSig = makeSignature(keccak256(abi.encode(
      anon,
      signal,
      proof
    )));

    vm.prank(anon);
    main.submitProof(
      idCommitment, // mock takes idCommitment as merkleTreeRoot
      signal,
      proofSig,
      0, // nullifierHash
      0, // externalNullifier
      proof
    );

    assertEq(main.balanceOf(anon), 1);
    assertTrue(main.addressActive(anon));

    // Jump forward 4 months, after expiration
    vm.warp(block.timestamp + (4 * 4 weeks));
    assertTrue(!main.addressActive(anon));

    vm.prank(address(1));
    vm.expectRevert();
    main.transferFrom(anon, address(1), idCommitment);

    main.transferFrom(anon, address(1), idCommitment);
    assertEq(main.balanceOf(anon), 0);
    assertEq(main.balanceOf(address(1)), 1);

  }

  function makeSignature(bytes32 hash) internal view returns(bytes memory) {
    bytes32 ethSignedHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethSignedHash);
    return abi.encodePacked(r, s, v);
  }

}
