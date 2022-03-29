// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract JaxBridgeETHV2 {

  uint chainId;
  
  uint public fee_percent = 5e5; // 0.5 %
  uint public minimum_fee_amount = 50; // 50 WJXN

  address public admin;

  uint public penalty_amount = 0;

  address public penalty_wallet;

  IERC20 public wjxn = IERC20(0xA25946ec9D37dD826BbE0cbDbb2d79E69834e41e); //0xcA1262e77Fb25c0a4112CFc9bad3ff54F617f2e6


  enum RequestStatus {Init, Proved, Rejected, Expired, Released}

  struct Request {
    uint srcChainId;
    uint destChainId;
    uint amount;
    address to;
    uint date;
    bytes32 depositHash;
  }

  Request[] public requests;

  mapping(address => uint[]) public user_requests;

  address[] public bridge_operators;
  mapping(address => uint) operating_limits;

  mapping(bytes32 => bool) proccessed_deposit_hashes;

  event Deposit(uint indexed request_id, bytes32 indexed depositHash, address indexed to, uint amount, uint64 srcChainId, uint64 destChainId, uint128 date);
  event Release(
    uint indexed request_id, 
    bytes32 indexed depositHash, 
    address indexed to, 
    uint deposited_amount, 
    uint released_amount, 
    uint64 srcChainId, 
    uint64 destChainId, 
    uint128 deposited_date, 
    uint128 released_date,
    string txHash
  );
  event Reject_Request(uint request_id);
  event Set_Fee(uint fee_percent, uint minimum_fee_amount);
  event Set_Operating_Limit(address operator, uint operating_limit);
  event Set_Penalty_Wallet(address wallet);
  event Set_Admin(address admin);
  event Delete_Deposit_Addresses(uint[] ids);
  event Add_Penalty_Amount(uint amount, bytes32 info_hash);
  event Subtract_Penalty_Amount(uint amount, bytes32 info_hash);

  constructor() {
    admin = msg.sender;
    uint _chainId;
    assembly {
        _chainId := chainid()
    }
    chainId = _chainId;
    penalty_wallet = msg.sender;
  }

  modifier onlyAdmin() {
    require(admin == msg.sender, "Only Admin can perform this operation.");
    _;
  }

  modifier onlyOperator() {
    require(isBridgeOperator(msg.sender), "Not a bridge operator");
    _;
  }

  function deposit(uint amount) external onlyAdmin {
    wjxn.transferFrom(admin, address(this), amount);
  }

  function withdraw(uint amount) external onlyAdmin {
    wjxn.transfer(admin, amount);
  }

  function deposit(uint destChainId, uint amount) external payable {
    require(amount >= minimum_fee_amount, "Minimum amount");
    require(chainId != destChainId, "Invalid Destnation network");
    uint request_id = requests.length;
    bytes32 depositHash = keccak256(abi.encodePacked(request_id, msg.sender, chainId, destChainId, amount, block.timestamp));
    Request memory request = Request({
      srcChainId: chainId,
      destChainId: destChainId,
      amount: amount,
      to: msg.sender,
      date: block.timestamp,
      depositHash: depositHash
    });
    requests.push(request);
    wjxn.transferFrom(msg.sender, address(this), amount);
    emit Deposit(request_id, depositHash, msg.sender, amount, uint64(chainId), uint64(destChainId), uint128(block.timestamp));
  }

  function release(
    uint request_id,
    address to,
    uint srcChainId,
    uint destChainId,
    uint amount,
    uint deposited_date,
    bytes32 depositHash,
    string calldata txHash
  ) external onlyOperator {
    require( destChainId == chainId, "Incorrect destination network" );
    require( depositHash == keccak256(abi.encodePacked(request_id, to, srcChainId, chainId, amount)), "Incorrect deposit hash");

    uint fee_amount = amount * fee_percent / 1e8;
    if(fee_amount < minimum_fee_amount) fee_amount = minimum_fee_amount;
    wjxn.transfer(to, amount - fee_amount);
    if(penalty_amount > 0) {
      if(penalty_amount > fee_amount) {
        wjxn.transfer(penalty_wallet, fee_amount);
        penalty_amount -= fee_amount;
      }
      else {
        wjxn.transfer(penalty_wallet, penalty_amount);
        wjxn.transfer(msg.sender, fee_amount - penalty_amount);
        penalty_amount -= penalty_amount;
      }
    }
    else {
      wjxn.transfer(msg.sender, fee_amount);
    }
    operating_limits[msg.sender] -= amount;
    emit Release(request_id, depositHash, to, amount, amount - fee_amount, uint64(srcChainId), uint64(destChainId), uint128(deposited_date), uint128(block.timestamp), txHash);
  }

  function withdrawByAdmin(address token, uint amount) external onlyAdmin {
      IERC20(token).transfer(msg.sender, amount);
  }

  function add_bridge_operator(address operator, uint operating_limit) external onlyAdmin {
    for(uint i = 0; i < bridge_operators.length; i += 1) {
      if(bridge_operators[i] == operator)
        revert("Already exists");
    }
    bridge_operators.push(operator);
    operating_limits[operator] = operating_limit;
  }

  function isBridgeOperator(address operator) public view returns(bool) {
    uint i = 0;
    for(; i < bridge_operators.length; i += 1) {
      if(bridge_operators[i] == operator)
        return true;
    } 
    return false;
  }

  function set_operating_limit(address operator, uint operating_limit) external onlyAdmin {
    require(isBridgeOperator(operator), "Not a bridge operator");
    operating_limits[operator] = operating_limit;
    emit Set_Operating_Limit(operator, operating_limit);
  }

  function set_fee(uint _fee_percent, uint _minimum_fee_amount) external onlyAdmin {
    fee_percent = _fee_percent;
    minimum_fee_amount = _minimum_fee_amount;
    emit Set_Fee(_fee_percent, _minimum_fee_amount);
  }

  function set_penalty_wallet(address _penalty_wallet) external onlyAdmin {
    penalty_wallet = _penalty_wallet;
    emit Set_Penalty_Wallet(_penalty_wallet);
  }

  function set_admin(address _admin) external onlyAdmin {
    admin = _admin;
    emit Set_Admin(_admin);
  }

  function add_penalty_amount(uint amount, bytes32 info_hash) external onlyAdmin {
    penalty_amount += amount;
    emit Add_Penalty_Amount(amount, info_hash);
  }

  function subtract_penalty_amount(uint amount, bytes32 info_hash) external onlyAdmin {
    require(penalty_amount >= amount, "over penalty amount");
    emit Subtract_Penalty_Amount(amount, info_hash);
  }
}
