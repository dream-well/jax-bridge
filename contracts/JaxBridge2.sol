// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract JaxBridge2 {

  uint chainId;
  address public admin;
  IERC20 public token;
   mapping(address => mapping(uint => bool)) public processedNonces;
  mapping(address => uint) public nonces;

  enum Step { Deposit, Withdraw }
  event Transfer(
    address from,
    address to,
    uint destChainId,
    uint amount,
    uint date,
    uint nonce,
    bytes32 txId,
    Step indexed step
  );

  constructor() {
    admin = msg.sender;
    uint _chainId;
    assembly {
        _chainId := chainid()
    }
    chainId = _chainId;
  }

  modifier onlyAdmin() {
    require(admin == msg.sender, "Only Admin can perform this operation.");
    _;
  }

  function setToken(address _token) external onlyAdmin {
    token = IERC20(_token);
  }

  function deposit(uint amount) external onlyAdmin {
    token.transferFrom(admin, address(this), amount);
  }

  function withdraw(uint amount) external onlyAdmin {
    token.transfer(admin, amount);
  }

  function deposit(address to, uint destChainId, uint amount, uint nonce) external {
    require(nonces[msg.sender] == nonce, 'transfer already processed');
    nonces[msg.sender] += 1;
    token.transferFrom(msg.sender, address(this), amount);
    bytes32 txId = keccak256(abi.encodePacked(msg.sender, to, chainId, destChainId, amount, nonce));
    emit Transfer(
      msg.sender,
      to,
      destChainId,
      amount,
      block.timestamp,
      nonce,
      txId,
      Step.Deposit
    );
  }

  function withdraw(
    address from, 
    address to, 
    uint srcChainId,
    uint amount, 
    uint nonce,
    bytes32 txId
  ) external {
    bytes32 _txId = keccak256(abi.encodePacked(
      from, 
      to, 
      srcChainId,
      chainId,
      amount,
      nonce
    ));
    require(_txId == txId , 'wrong txId');
    require(processedNonces[from][nonce] == false, 'transfer already processed');
    processedNonces[from][nonce] = true;
    require(token.balanceOf(address(this)) >= amount, 'insufficient pool');
    token.transfer(to, amount);
    emit Transfer(
      from,
      to,
      chainId,
      amount,
      block.timestamp,
      nonce,
      txId,
      Step.Withdraw
    );
  }

}
