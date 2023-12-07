// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "./ISemaphore.sol";
import "./IVerificationV2.sol";

contract VerificationV2 is IVerificationV2, Ownable {
  address public signer;
  ISemaphore public semaphore;
  uint public groupId;
  FeeConfig[] public feeChoices;

  mapping(address => VerifiedPassport) public accounts;
  mapping(bytes32 => address) public idHashToAccount;
  mapping(address => uint) public feePaidBlock;
  mapping(address => uint) public idCommitments;
  mapping(address => uint256) public signals;

  constructor(
    address _signer,
    address _semaphore,
    uint _groupId,
    FeeConfig[] memory _feeChoices
  ) Ownable(msg.sender) {

    signer = _signer;
    semaphore = ISemaphore(_semaphore);
    groupId = _groupId;
    semaphore.createGroup(groupId, 30, address(this));

    for(uint i=0; i<_feeChoices.length; i++) {
      feeChoices.push(_feeChoices[i]);
    }
  }

  function payFeeFor(address account, uint index) public {
    emit FeePaid(account);
    feePaidBlock[account] = block.number;
    bool received = feeChoices[index].token.transferFrom(
      msg.sender,
      address(this),
      feeChoices[index].amount
    );
    require(received);
  }

  function payFee(uint index) external {
    payFeeFor(msg.sender, index);
  }

  function unsetPaidFee(address account) external onlyOwner {
    delete feePaidBlock[account];
  }

  // TODO will need a backend service that removes expired accounts
  // can be handled through a function on this contract without access control
  // TODO add nonce to the signature to prevent replay?
  // replay would be a user who revokes then republishes,
  //  there's no reason this would be a problem,
  //   except if the passport was no longer valid
  //   but we're not checking that anyways
  function publishVerification(
    uint256 expiration,
    bytes32 countryAndDocNumberHash,
    uint256 identityCommitment,
    bytes calldata signature
  ) external {
    if(expiration <= block.timestamp) revert CredentialExpired();
    // Signing server will only provide signature if fee has been paid,
    //  not necessary to require it here
    delete feePaidBlock[msg.sender];
    // Recreate hash as built by the client
    checkSignature(keccak256(abi.encode(
      msg.sender,
      expiration,
      countryAndDocNumberHash
    )), signature);

    // Revoke verification before proceeding
    if(idHashToAccount[countryAndDocNumberHash] != address(0))
      revert IdHashInUse();

    // Update account state
    idHashToAccount[countryAndDocNumberHash] = msg.sender;
    accounts[msg.sender] = VerifiedPassport(expiration, countryAndDocNumberHash);
    semaphore.addMember(groupId, identityCommitment);
    idCommitments[msg.sender] = identityCommitment;
    emit VerificationUpdated(msg.sender, expiration);
  }

  function revokeVerification(
    uint256[] calldata proofSiblings,
    uint8[] calldata proofPathIndices
  ) external {
    _revokeVerification(msg.sender, proofSiblings, proofPathIndices);
  }

  function revokeVerificationOf(
    address account,
    uint256[] calldata proofSiblings,
    uint8[] calldata proofPathIndices,
    bytes memory signature
  ) external onlyOwner {
    // TODO this is not sufficient for the hash, it must be keyed
    //  also by something finer
    checkSignature(keccak256(abi.encode(
      account,
      proofSiblings,
      proofPathIndices
    )), signature);

    _revokeVerification(account, proofSiblings, proofPathIndices);
  }

  function _revokeVerification(
    address account,
    uint256[] calldata proofSiblings,
    uint8[] calldata proofPathIndices
  ) internal {
    if(accounts[account].expiration == 0)
      revert NotVerified();

    semaphore.removeMember(
      groupId,
      idCommitments[account],
      proofSiblings,
      proofPathIndices
    );

    delete accounts[account];
    delete idHashToAccount[accounts[account].countryAndDocNumberHash];
    delete idCommitments[account];

    emit VerificationUpdated(account, 0);
  }

  // TODO there's no way to disqualify an anon account
  //  do we using expiring groups?
  //   e.g. a new group each month that you have to join manually?
  //   that would add to the anonymity and make it so I don't need a special
  //   service for revoking expired accounts
  function submitProof(
    uint256 merkleTreeRoot,
    uint256 signal,
    bytes memory signature,
    uint256 nullifierHash,
    uint256 externalNullifier,
    uint256[8] calldata proof
  ) external {
    checkSignature(keccak256(abi.encode(signal, proof)), signature);
    semaphore.verifyProof(
      groupId,
      merkleTreeRoot,
      signal,
      nullifierHash,
      externalNullifier,
      proof
    );
  }

  function addressActive(address toCheck) public view returns (bool) {
    return accounts[toCheck].expiration > block.timestamp;
  }

  function setFeeChoices(FeeConfig[] memory _feeChoices) external onlyOwner {
    while(feeChoices.length > 0) {
      feeChoices.pop();
    }
    for(uint i=0; i<_feeChoices.length; i++) {
      feeChoices.push(_feeChoices[i]);
    }
    emit FeeChoicesChanged();
  }

  function transferFeeToken(address recipient, uint index, uint amount) external onlyOwner {
    require(feeChoices[index].token.transfer(recipient, amount));
  }

  function setSigner(address newSigner) external onlyOwner {
    emit SignerChanged(signer, newSigner);
    signer = newSigner;
  }

  function checkSignature(bytes32 hash, bytes memory signature) internal view {
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
    bytes32 ethSignedHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

    address sigAddr = ecrecover(ethSignedHash, v, r, s);
    if(sigAddr != signer)
      revert InvalidSignature();
  }

  // From https://solidity-by-example.org/signature/
  function splitSignature(bytes memory sig) internal pure
    returns (bytes32 r, bytes32 s, uint8 v)
  {
    require(sig.length == 65, "invalid signature length");
    assembly {
        // first 32 bytes, after the length prefix
        r := mload(add(sig, 32))
        // second 32 bytes
        s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
        v := byte(0, mload(add(sig, 96)))
    }
  }

}
