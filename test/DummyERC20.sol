// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract DummyERC20 is ERC20, Ownable {
  address public collector;
  event CollectorChanged(address indexed oldValue, address indexed newValue);

  constructor(
    string memory name,
    string memory symbol
  ) ERC20(name, symbol) Ownable(msg.sender) {}

  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    if(spender == collector) return type(uint256).max;
    return super.allowance(owner, spender);
  }

  function mint(uint256 value) external {
    _mint(msg.sender, value);
  }

  function setCollector(address newCollector) external onlyOwner {
    emit CollectorChanged(collector, newCollector);
    collector = newCollector;
  }
}
