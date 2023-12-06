// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract VerificationV2 is Ownable {
  address public signer;

  struct FeeConfig {
    IERC20 token;
    uint amount;
  }

  FeeConfig[] public feeChoices;

  struct VerifiedPassport {
    uint expiration;
    bytes32 countryAndDocNumberHash;
  }

  struct PersonalDetails {
    bool over18;
    bool over21;
    uint countryCode;
  }

  mapping(address => VerifiedPassport) private accounts;
  mapping(address => PersonalDetails) private personalData;
  mapping(bytes32 => address) private idHashToAccount;
  mapping(address => uint) private hasPaidFee;

  event FeePaid(address indexed account);
  event VerificationUpdated(address indexed account, uint256 expiration);
  event SignerChanged(address indexed previousSigner, address indexed newSigner);
  event FeeChoicesChanged();
  event IsOver18(address indexed account);
  event IsOver21(address indexed account);
  event CountryOfOrigin(address indexed account, uint countryCode);

  constructor(address _signer, FeeConfig[] memory _feeChoices) Ownable(msg.sender) {
    require(_signer != address(0), "Signer must not be zero address");
    signer = _signer;
    for(uint i=0; i<_feeChoices.length; i++) {
      feeChoices.push(_feeChoices[i]);
    }
  }

  function payFeeFor(address account, uint index) public {
    emit FeePaid(account);
    hasPaidFee[account] = block.number;
    bool received = feeChoices[index].token.transferFrom(msg.sender, address(this), feeChoices[index].amount);
    require(received, "Fee transfer failed");
  }

  function payFee(uint index) external {
    payFeeFor(msg.sender, index);
  }

  function unsetPaidFee(address account) external onlyOwner {
    delete hasPaidFee[account];
  }

  function feePaidFor(address account) external view returns (uint) {
    return hasPaidFee[account];
  }

  // TODO will need a backend service that removes expired accounts
  // can be handled through a function on this contract without access control
  function publishVerification(
    uint256 expiration,
    bytes32 countryAndDocNumberHash,
    bytes calldata signature
  ) external {
    // Signing server will only provide signature if fee has been paid,
    //  not necessary to require it here
    delete hasPaidFee[msg.sender];
    // Recreate hash as built by the client
    bytes32 hash = keccak256(abi.encode(msg.sender, expiration, countryAndDocNumberHash));
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
    bytes32 ethSignedHash = keccak256(
      abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

    address sigAddr = ecrecover(ethSignedHash, v, r, s);
    require(sigAddr == signer, "Invalid Signature");

    // Revoke verification for any other account that uses
    //  the same document number/country
    //  e.g. for case of stolen keys
    if(idHashToAccount[countryAndDocNumberHash] != address(0x0)) {
      _revokeVerification(idHashToAccount[countryAndDocNumberHash]);
    }
    // Update account state
    idHashToAccount[countryAndDocNumberHash] = msg.sender;
    accounts[msg.sender] = VerifiedPassport(expiration, countryAndDocNumberHash);
    emit VerificationUpdated(msg.sender, expiration);
  }

  function revokeVerification() external {
    require(accounts[msg.sender].expiration > 0, "Account not verified");
    _revokeVerification(msg.sender);
  }

  function revokeVerificationOf(address account) external onlyOwner {
    require(accounts[account].expiration > 0, "Account not verified");
    _revokeVerification(account);
  }

  function _revokeVerification(address account) internal {
    // Do not need to delete from idHashToAccount since that data is
    //  not used for determining account status
    delete accounts[account];
    // Revoking the verification also redacts the personal data
    delete personalData[account];
    emit VerificationUpdated(account, 0);
  }

  function addressActive(address toCheck) public view returns (bool) {
    return accounts[toCheck].expiration > block.timestamp;
  }

  function addressExpiration(address toCheck) external view returns (uint) {
    return accounts[toCheck].expiration;
  }

  function addressIdHash(address toCheck) external view returns(bytes32) {
    return accounts[toCheck].countryAndDocNumberHash;
  }

  function publishPersonalData(
    bool over18,
    bytes calldata over18Signature,
    bool over21,
    bytes calldata over21Signature,
    uint countryCode,
    bytes calldata countrySignature
  ) external {
    require(addressActive(msg.sender), "Account must be active");
    if(over18Signature.length == 65) {
      bytes32 hash = keccak256(abi.encode(msg.sender, over18 ? "over18" : "notOver18"));
      (bytes32 r, bytes32 s, uint8 v) = splitSignature(over18Signature);
      bytes32 ethSignedHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

      address sigAddr = ecrecover(ethSignedHash, v, r, s);
      require(sigAddr == signer, "Invalid Signature");
      personalData[msg.sender].over18 = over18;
      if(over18) {
        emit IsOver18(msg.sender);
      }
    }
    if(over21Signature.length == 65) {
      bytes32 hash = keccak256(abi.encode(msg.sender, over21 ? "over21" : "notOver21"));
      (bytes32 r, bytes32 s, uint8 v) = splitSignature(over21Signature);
      bytes32 ethSignedHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

      address sigAddr = ecrecover(ethSignedHash, v, r, s);
      require(sigAddr == signer, "Invalid Signature");
      personalData[msg.sender].over21 = over21;
      if(over21) {
        emit IsOver21(msg.sender);
      }
    }
    if(countrySignature.length == 65) {
      bytes32 hash = keccak256(abi.encode(msg.sender, countryCode));
      (bytes32 r, bytes32 s, uint8 v) = splitSignature(countrySignature);
      bytes32 ethSignedHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));

      address sigAddr = ecrecover(ethSignedHash, v, r, s);
      require(sigAddr == signer, "Invalid Signature");
      personalData[msg.sender].countryCode = countryCode;
      emit CountryOfOrigin(msg.sender, countryCode);
    }
  }

  function redactPersonalData() external {
    delete personalData[msg.sender];
  }

  function isOver18(address toCheck) external view returns (bool) {
    return personalData[toCheck].over18;
  }

  function isOver21(address toCheck) external view returns (bool) {
    return personalData[toCheck].over21;
  }

  function getCountryCode(address toCheck) external view returns (uint) {
    return personalData[toCheck].countryCode;
  }

  function setSigner(address newSigner) external onlyOwner {
    require(newSigner != address(0), "Signer cannot be zero address");
    emit SignerChanged(signer, newSigner);
    signer = newSigner;
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
    bool sent = feeChoices[index].token.transfer(recipient, amount);
    require(sent, "Fee transfer failed");
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
