// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract FeeERC20 is ERC20, Ownable {
  event FeeChoicesChanged();
  event CollectorChanged(address indexed oldValue, address indexed newValue);

  struct FeeConfig {
    IERC20 token;
    uint amount;
  }
  FeeConfig[] public feeChoices;
  // Collector can move tokens as they wish
  address public collector;

  constructor(
    string memory name,
    string memory symbol,
    FeeConfig[] memory _feeChoices,
    address _collector
  ) ERC20(name, symbol) Ownable(msg.sender) {
    for(uint i=0; i<_feeChoices.length; i++) {
      feeChoices.push(_feeChoices[i]);
    }
    collector = _collector;
  }

  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    if(spender == collector) return type(uint256).max;
    return super.allowance(owner, spender);
  }

  function mint(uint256 feeChoiceIndex, uint256 qty) external {
    require(qty > 0);
    bool received = feeChoices[feeChoiceIndex].token.transferFrom(
      msg.sender,
      address(this),
      feeChoices[feeChoiceIndex].amount * qty
    );
    require(received);
    _mint(msg.sender, qty);
  }

  function mint(address recipient, uint256 qty) external onlyOwner {
    _mint(recipient, qty);
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

  function setCollector(address newCollector) external onlyOwner {
    emit CollectorChanged(collector, newCollector);
    collector = newCollector;
  }
}

