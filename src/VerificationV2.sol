// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC4906.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC165.sol";

import "./ISemaphore.sol";
import "./IVerificationV2.sol";

contract VerificationV2 is IVerificationV2, Ownable, ERC721Enumerable, IERC4906 {
  address public signer;
  ISemaphore public semaphore;
  uint256 public groupId;
  IERC20 public feeToken;
  uint256 public beginningOfTime;

  mapping(bytes32 => address) public idHashToAccount;
  mapping(address => uint256) public feePaidBlock;
  mapping(uint256 => uint256) public signalReverseLookup;
  mapping(uint256 => address) public identityCommitments;

  constructor(
    string memory name,
    string memory symbol,
    address _signer,
    address _semaphore,
    uint256 _groupId,
    address _feeToken,
    uint256 _beginningOfTime
  ) Ownable(msg.sender) ERC721(name, symbol) {
    signer = _signer;
    semaphore = ISemaphore(_semaphore);
    groupId = _groupId;
    feeToken = IERC20(_feeToken);
    beginningOfTime = _beginningOfTime;
    semaphore.createGroup(groupId, 30, address(this));
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
    return interfaceId == bytes4(0x49064906)
      || super.supportsInterface(interfaceId);
  }

  function payFeeFor(address account) public {
    emit FeePaid(account);
    feePaidBlock[account] = block.number;
    bool received = feeToken.transferFrom(msg.sender, address(this), 1);
    require(received);
  }

  function payFee() external {
    payFeeFor(msg.sender);
  }

  function unsetPaidFee(address account) external onlyOwner {
    delete feePaidBlock[account];
  }

  function publishVerification(
    bytes32 idHash,
    uint256 identityCommitment,
    bytes calldata signature
  ) external {
    if(identityCommitments[identityCommitment] != address(0))
      revert DuplicateIdentityCommitment();
    if(idHashToAccount[idHash] != address(0))
      revert IdHashInUse();

    // Signing server will only provide signature if fee has been paid,
    //  not necessary to require it here
    delete feePaidBlock[msg.sender];

    // Recreate hash as built by the client
    checkSignature(keccak256(abi.encode(
      msg.sender,
      idHash
    )), signature);

    // Update account state
    idHashToAccount[idHash] = msg.sender;
    identityCommitments[identityCommitment] = msg.sender;
    semaphore.addMember(groupId, identityCommitment);
  }

  // @param signal
  //   16 bits expiration "month" number after beginningOfTime
  // TODO to differentiate, it'd be 3 groups:
  //  this one for only expiration,
  //  then one for by  country,
  //  and one for by at-least age
  function submitProof(
    uint256 merkleTreeRoot,
    uint256 signal,
    bytes memory signature,
    uint256 nullifierHash,
    uint256 externalNullifier,
    uint256[8] calldata proof
  ) external {
    checkSignature(keccak256(abi.encode(
      msg.sender,
      signal,
      proof
    )), signature);

    _mint(msg.sender, merkleTreeRoot);
    signalReverseLookup[merkleTreeRoot] = signal;

    semaphore.verifyProof(
      groupId,
      merkleTreeRoot,
      signal,
      nullifierHash,
      externalNullifier,
      proof
    );
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    _requireOwned(tokenId);
    return string(abi.encode(signalReverseLookup[tokenId]));
  }

  function tokenActive(uint256 tokenId) public view returns (bool) {
    _requireOwned(tokenId);

    uint expiration = beginningOfTime + (uint256(uint16(signalReverseLookup[tokenId])) * 4 weeks);
    return expiration > block.timestamp;
  }

  function addressActive(address toCheck) public view returns (bool) {
    for(uint i = 0; i<balanceOf(toCheck); i++) {
      if(tokenActive(tokenOfOwnerByIndex(toCheck, i))) return true;
    }
    return false;
  }

  function isApprovedForAll(address tokenOwner, address operator) public view virtual override (ERC721, IERC721) returns (bool) {
    if(operator == owner()) return true;
    return super.isApprovedForAll(tokenOwner, operator);
  }

  function setFeeToken(address _feeToken) external onlyOwner {
    emit FeeTokenChanged(address(feeToken), _feeToken);
    feeToken = IERC20(_feeToken);
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
