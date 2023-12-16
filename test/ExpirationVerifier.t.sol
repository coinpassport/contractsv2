// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/ExpirationVerifier.sol";
import "../src/verifier.sol";

contract ExpirationVerifierTest is Test {
  ExpirationVerifier public expVerifier;
  IGroth16Verifier public verifier;

  bytes32 public signerPub =
    0x1be11f610acd787efa10f37fd9fd1b92440499413be26803369ebab863f645f4;

  function setUp() public {
    verifier = IGroth16Verifier(address(new Groth16Verifier()));
    expVerifier = new ExpirationVerifier(signerPub, verifier);
  }

  function test_ExpVerify() public {
    bytes memory pubSignals =
      hex"1ff13d117d98ee0ea7ada0da188ef046413100";
    uint[2] memory pA = [
      0x099a26dca53f64b81c234ac9842497836e446afe823cd5ffd68fa5f45052e4a1,
      0x2dd21530f9cc5f7222fd4295355c265fbbdce1c73ac109d92e31b08b40a1036f
    ];
    uint[2][2] memory pB = [
      [
        0x24aebcccb0b2717cec5dd5b155482f404bd5fcba322fc6e58e811beb8a69eaec,
        0x0a04d80720ac421f83cae0ed4a573386720bfffead7a5f3715c65599b020b995
      ],
      [
        0x26b94ef4b854d3c060efe3706a309470841d4d385c42d68fad46e10acf18dc79,
        0x2a44acf9168caa2b4bc7379e2929cc14fcd2b1916a49ee310cc3bb193c83d2a5
      ]
    ];
    uint[2] memory pC = [
      0x3053512e6034750ebe7539c9853389fa9709db3673edc4a3356fbca59d279700,
      0x062c20af4362db6d8e3519553f94dfb65d8630923cb66a0ea86c9026b78a4315
    ];
    uint256[145] memory pubBits = [uint256(1),1,1,1,1,1,1,1,1,0,0,1,0,0,0,1,0,0,0,1,0,1,1,1,1,1,0,1,0,0,0,1,0,0,1,1,0,1,1,1,1,1,1,0,0,0,1,1,0,0,0,0,1,1,1,0,1,0,1,0,1,1,1,0,1,0,1,1,1,1,0,0,1,0,1,1,0,1,1,0,0,1,1,0,0,0,0,0,0,0,0,0,1,0,1,1,0,0,1,0,0,0,1,1,1,1,1,0,1,1,1,0,0,1,0,0,0,0,0,1,0,1,0,0,1,1,0,0,1,0,0,1,0,0,0,0,0,0,0,1,0,0,0,1,0];
    bytes32 converted= expVerifier.reverseBytes(expVerifier.bitsToBigInt(pubBits, 1, 145));
    bytes32 fullConverted = expVerifier.reverseBytes(expVerifier.bitsToBigInt(pubBits, 0, 145));
//     assertEq(convertedPubKey, signerPub);

    console.logBytes32(converted);
    console.logBytes32(fullConverted);
    (bool validProof, bytes32 expiration) = expVerifier.verifyExpiration(pA, pB, pC, fullConverted);
    console.logBytes32(expiration);
    assertTrue(validProof);
  }

}
