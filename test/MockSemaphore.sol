//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract MockSemaphore {
  mapping(uint256 => address) public groupAdmin;
  mapping(uint256 => uint256[]) public commitmentsByGroup;
  mapping(uint256 => uint256) public proofCount;

  function createGroup(uint256 groupId, uint256, address admin) external {
    require(groupAdmin[groupId] == address(0));
    groupAdmin[groupId] = admin;
  }

  function addMember(uint256 groupId, uint256 identityCommitment) external {
    require(groupAdmin[groupId] == msg.sender);
    require(!hasMember(groupId, identityCommitment));
    commitmentsByGroup[groupId].push(identityCommitment);
  }

  function hasMember(uint256 groupId, uint256 identityCommitment) public view returns(bool) {
    for(uint i = 0; i<commitmentsByGroup[groupId].length; i++) {
      if(commitmentsByGroup[groupId][i] == identityCommitment) {
        return true;
      }
    }
    return false;
  }

  // XXX: Pass a member's commitment as the merkleTreeRoot to pass this
  function verifyProof(
    uint256 groupId,
    uint256 merkleTreeRoot,
    uint256,
    uint256,
    uint256,
    uint256[8] calldata
  ) external {
    require(hasMember(groupId, merkleTreeRoot));
    proofCount[groupId]++;
  }
}
