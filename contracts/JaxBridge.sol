// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract JaxBridge {

  uint chainId;
  uint fee;
  
  address public admin;
  address public verifier;
  address public fee_wallet;

  IERC20 public wjxn;
  mapping(address => mapping(string => bool)) public processedTxs;

  event Deposit(
    address from,
    address to,
    uint destChainId,
    uint amount,
    uint date,
    string txHash
  );

  event Withdraw(
    address from,
    address to,
    uint destChainId,
    uint amount,
    uint date,
    string txHash,
    bytes signature
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

  function setToken(address _wjxn) external onlyAdmin {
    wjxn = IERC20(_wjxn);
  }

  function deposit(uint amount) external onlyAdmin {
    wjxn.transferFrom(admin, address(this), amount);
  }

  function withdraw(uint amount) external onlyAdmin {
    wjxn.transfer(admin, amount);
  }

  function deposit(address to, uint destChainId, uint amount, string calldata txHash) external {
    wjxn.transferFrom(msg.sender, address(this), amount);
    emit Deposit(
      msg.sender,
      to,
      destChainId,
      amount,
      block.timestamp,
      txHash
    );
  }

  function withdraw(
    address from, 
    address to, 
    uint srcChainId,
    uint amount, 
    string calldata txHash,
    bytes calldata signature
  ) external onlyAdmin {
    bytes32 message = prefixed(keccak256(abi.encodePacked(
      from, 
      to, 
      srcChainId,
      chainId,
      amount,
      txHash
    )));
    require(recoverSigner(message, signature) == verifier , 'wrong signature');
    require(processedTxs[from][txHash] == false, 'transfer already processed');
    processedTxs[from][txHash] = true;
    require(wjxn.balanceOf(address(this)) >= amount, 'insufficient pool');
    wjxn.transfer(to, amount);
    emit Withdraw(
      from,
      to,
      chainId,
      amount,
      block.timestamp,
      txHash,
      signature
    );
  }

  function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(
      '\x19Ethereum Signed Message:\n32', 
      hash
    ));
  }

  function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address)
  {
    uint8 v;
    bytes32 r;
    bytes32 s;
  
    (v, r, s) = splitSignature(sig);
  
    return ecrecover(message, v, r, s);
  }

  function splitSignature(bytes memory sig)
    internal
    pure
    returns (uint8, bytes32, bytes32)
  {
    require(sig.length == 65);
  
    bytes32 r;
    bytes32 s;
    uint8 v;
  
    assembly {
        // first 32 bytes, after the length prefix
        r := mload(add(sig, 32))
        // second 32 bytes
        s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
        v := byte(0, mload(add(sig, 96)))
    }
  
    return (v, r, s);
  }
}
