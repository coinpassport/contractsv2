// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/Test.sol";

import "./IGroth16Verifier.sol";

contract ExpirationVerifier is Ownable {
    bytes32 public signerPubKey;
    IGroth16Verifier public verifier;

    event SignerPubKeyChanged(bytes32 oldPubKey, bytes32 newPubKey);
    error InvalidSigner();

    constructor(
      bytes32 _signerPubKey,
      IGroth16Verifier _verifier
    ) Ownable(msg.sender) {
      signerPubKey = _signerPubKey;
      verifier = _verifier;
    }

    function setSignerPubKey(bytes32 _signerPubKey) external onlyOwner {
      emit SignerPubKeyChanged(signerPubKey, _signerPubKey);
      signerPubKey = _signerPubKey;
    }

    function verifyExpiration(
      uint[2] calldata _pA,
      uint[2][2] calldata _pB,
      uint[2] calldata _pC,
      bytes32 _pubSignals
    ) public view returns (bool, bytes32) {
      uint[145] memory pubBits = bytesToBitsArray(_pubSignals);
      for(uint i =0; i< 17; i++) {
        console.logUint(pubBits[i]);
      }
      console.logString('fooobar');
      for(uint i =140; i< 145; i++) {
        console.logUint(pubBits[i]);
      }
      bytes32 convertedExp = reverseBytes(bitsToBigInt(pubBits, 1, 1+16));
      // Only half the key fits with the max contract size 24kb
      bytes32 convertedPubKey = bitsToBigInt(pubBits, 1+16, 1+16+128);

//       if(convertedPubKey != signerPubKey) revert InvalidSigner();
      console.logBytes32(signerPubKey);
      console.logBytes32(convertedPubKey);
      console.logBytes32(convertedExp);
      return (verifier.verifyProof(_pA, _pB, _pC, pubBits), convertedExp);
    }

  // Function to reverse bytes of a bytes32
  function reverseBytes(bytes32 input) public pure returns (bytes32) {
      bytes32 reversed;
      for (uint i = 0; i < 32; i++) {
          reversed |= (input & bytes32(0xFF << (i * 8))) >> (i * 8) << ((31 - i) * 8);
      }
      return reversed;
  }
  function bitsToBigInt(uint256[145] memory bits, uint256 startBit, uint256 stopBit) public pure returns (bytes32) {
      require(startBit < stopBit && stopBit <= bits.length * 8, "Invalid start or stop bit");

      bytes32 result = 0;

      for (uint256 i = startBit; i < stopBit; i += 8) {
          uint256 byteValue = 0;
          for (uint256 j = 0; j < 8; j++) {
              if (i + j >= stopBit) break; // Stop if exceeding stopBit

              uint256 bitIndex = i + j;
              uint256 bit = bits[bitIndex / 8 * 8 + (bitIndex % 8)];
              require(bit == 0 || bit == 1, "Invalid bit value");
              byteValue |= bit << (j % 8);
          }
          result |= bytes32(byteValue) << ((i - startBit) / 8 * 8);
      }

      return result;
  }

  // This function written by ChatGPT4
  function bytesToBitsArray(bytes32 data) public pure returns (uint256[145] memory bitsArray) {

      uint256 bitCount = 0;
      for (uint256 i = 0; i < 32; i++) {
          // Extract each bit from the byte
          for (uint256 j = 0; j < 8; j++) {
              // Check if the total bits reached 337
              if (bitCount == 145) {
                  return bitsArray;
              }

              // Extract the j-th bit of the i-th byte
              uint256 bit = (uint256(uint8(data[i])) >> j) & 1;
              bitsArray[bitCount] = bit;
              bitCount++;
          }
      }
      return bitsArray;
  }
 }
