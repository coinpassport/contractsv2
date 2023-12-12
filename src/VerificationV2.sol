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
  GroupDetails[] public groups;
  IERC20 public feeToken;
  uint256 public beginningOfTime;

  mapping(bytes32 => uint256) public idHashExpiration;
  mapping(bytes32 => address) public idHashToAccount;
  mapping(address => bytes32) public accountToIdHash;
  mapping(address => uint256) public feePaidBlock;
  mapping(uint256 => uint256) public signalReverseLookup;
  mapping(uint256 => address) public reverseIdentityCommitments;
  mapping(uint256 => uint256[]) public identityCommitments;
  mapping(bytes32 => mapping(uint256 => bool)) public idHashInGroup;
  mapping(uint256 => uint256) public tokenGroupId;

  constructor(
    string memory name,
    string memory symbol,
    address _signer,
    address _semaphore,
    address _feeToken,
    uint256 _groupId,
    uint256 _groupDepth
  ) Ownable(msg.sender) ERC721(name, symbol) {
    signer = _signer;
    semaphore = ISemaphore(_semaphore);
    feeToken = IERC20(_feeToken);
    groups.push(GroupDetails(_groupId, _groupDepth, 0));
    semaphore.createGroup(_groupId, _groupDepth, address(this));
  }

  function groupCount() public view returns(uint256) {
    return groups.length;
  }

  function groupIndex() public view returns (uint256) {
    uint256 index = groups.length - 1;
    while(groups[index].startTime > block.timestamp) {
      index--;
    }
    return index;
  }

  function groupId() public view returns (uint256) {
    return groups[groupIndex()].id;
  }

  function groupDepth() public view returns (uint256) {
    return groups[groupIndex()].depth;
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
    uint256 expiration,
    bytes32 idHash,
    uint256 identityCommitment,
    bytes calldata signature
  ) external {
    if(reverseIdentityCommitments[identityCommitment] != address(0))
      revert DuplicateIdentityCommitment();
    if(expiration < block.timestamp)
      revert Expired();

    // Signing server will only provide signature if fee has been paid,
    //  not necessary to require it here
    delete feePaidBlock[msg.sender];

    checkSignature(keccak256(abi.encode(
      msg.sender,
      expiration,
      idHash
    )), signature);

    if(idHashToAccount[idHash] != address(0))
      delete accountToIdHash[idHashToAccount[idHash]];

    accountToIdHash[msg.sender] = idHash;
    idHashToAccount[idHash] = msg.sender;
    idHashExpiration[idHash] = expiration;
    reverseIdentityCommitments[identityCommitment] = msg.sender;
    identityCommitments[groupId()].push(identityCommitment);
    // If moving the idHash to new account, and the previous
    //  account had joined the group already,
    //  don't let this new account join again
    if(!idHashInGroup[idHash][groupId()]) {
      idHashInGroup[idHash][groupId()] = true;
      semaphore.addMember(groupId(), identityCommitment);
    }
  }

  function identityCommitmentCount() external view returns(uint) {
    return identityCommitments[groupId()].length;
  }

  function joinNewGroup(uint256 identityCommitment) external {
    bytes32 idHash = accountToIdHash[msg.sender];
    if(idHashExpiration[idHash] < block.timestamp)
      revert Inactive();
    if(idHashInGroup[idHash][groupId()])
      revert AlreadyInGroup();

    reverseIdentityCommitments[identityCommitment] = msg.sender;
    identityCommitments[groupId()].push(identityCommitment);
    idHashInGroup[idHash][groupId()] = true;
    semaphore.addMember(groupId(), identityCommitment);
  }

  function submitProof(
    uint256 merkleTreeRoot,
    // does everyone using the same signal enhance privacy?
    uint256 signal,
    uint256 nullifierHash,
    uint256 externalNullifier,
    uint256[8] calldata proof
  ) external {
    _mint(msg.sender, merkleTreeRoot);
    tokenGroupId[merkleTreeRoot] = groupId();
    signalReverseLookup[merkleTreeRoot] = signal;

    semaphore.verifyProof(
      groupId(),
      merkleTreeRoot,
      signal,
      nullifierHash,
      externalNullifier,
      proof
    );
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    _requireOwned(tokenId);
    if(tokenActive(tokenId)) {
      return "data:,Valid Anonymized Passport";
    } else {
      return "data:,Expired Anonymized Passport";
    }
  }

  function tokenActive(uint256 tokenId) public view returns (bool) {
    _requireOwned(tokenId);
    return tokenGroupId[tokenId] == groupId();
  }

  function addressActive(address toCheck) public view returns (bool) {
    for(uint i = 0; i<balanceOf(toCheck); i++) {
      if(tokenActive(tokenOfOwnerByIndex(toCheck, i))) return true;
    }
    return false;
  }

  function newGroup(
    uint256 newGroupId,
    uint256 depth,
    uint256 startTime
  ) external onlyOwner {
    emit GroupChanged(newGroupId, depth);
    groups.push(GroupDetails(newGroupId, depth, startTime));
    semaphore.createGroup(newGroupId, depth, address(this));
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
