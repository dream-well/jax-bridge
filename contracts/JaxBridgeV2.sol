// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract JaxBridgeV2 {

  uint chainId;
  
  uint fee = 50;

  address public admin;

  IERC20 public wjxn = IERC20(0xA25946ec9D37dD826BbE0cbDbb2d79E69834e41e);

  enum RequestStatus {Init, Proved, Rejected, Expired, Released}

  struct Request {
    uint amount;
    uint deposit_address_id;
    uint valid_until;
    address to;
    RequestStatus status;
    string from;
    string txHash;
  }

  string[] public deposit_addresses;
  bool[] public is_address_active;

  Request[] public requests;

  mapping(address => uint[]) public user_requests;

  address[] public bridge_operators;
  mapping(address => uint) operating_limits;

  event Create_Request(
    uint request_id,
    uint amount,
    string from
  );

  event Prove_Request(
    uint request_id
  );

  event Reject_Request(
    uint request_id
  );

  event Release(
    uint request_id,
    address from,
    uint amount
  );


  event Set_Fee(
    uint fee
  );


  event Set_Operating_Limit(
    address operator,
    uint operating_limit
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


  modifier bridgeOperator(uint amount) {
    require(isBridgeOperator(msg.sender), "Not a bridge operator");
    require(operating_limits[msg.sender] >= amount, "Amount exceeds operating limit");
    _;
    operating_limits[msg.sender] -= amount;
  }


  function deposit(uint amount) external onlyAdmin {
    wjxn.transferFrom(admin, address(this), amount);
  }

  function withdraw(uint amount) external onlyAdmin {
    wjxn.transfer(admin, amount);
  }

  function add_deposit_addresses(string[] calldata new_addresses) external {
    for(uint i = 0; i < new_addresses.length; i += 1) {
      deposit_addresses.push(new_addresses[i]);
      is_address_active.push(false);
    }
  }

  function create_request(uint amount, address to, string calldata from) external {
    require(amount >= 100, "Min amount 100");
    Request memory request;
    request.amount = amount;
    request.to = to;
    request.from = from;
    requests.push(request);
    uint request_id = requests.length - 1;
    user_requests[to].push(request_id);

    uint i = 0;
    for(; i <= deposit_addresses.length; i += 1) {
      if(!is_address_active[i])
        break;
    }
    require(i < deposit_addresses.length, "All deposit addresses are active");
    is_address_active[i] = true;
    request.deposit_address_id = i;
    request.valid_until = block.timestamp + 48 hours;
    emit Create_Request(request_id, amount, from);
  }

  function prove_request(uint request_id, string calldata txHash) external {
    Request storage request = requests[request_id];
    require(request.to == msg.sender, "Invalid account");
    require(request.status == RequestStatus.Init, "Invalid status");
    request.txHash = txHash;
    request.status = RequestStatus.Proved;
    emit Prove_Request(request_id);
  }

  function reject_request(uint request_id) external onlyAdmin {
    Request storage request = requests[request_id];
    // require(request.status == RequestStatus.Init, "Invalid status");
    request.status = RequestStatus.Rejected;
    emit Reject_Request(request_id);
  }

  function release(
    uint request_id,
    uint amount,
    string calldata from,
    address to,
    string calldata txHash
  ) external bridgeOperator(amount) {
    Request storage request = requests[request_id];
    require(request.amount == amount, "amount mismatch");
    require(keccak256(abi.encodePacked(request.from)) == keccak256(abi.encodePacked(from)), "Sender's address mismatch");
    require(request.to == to, "destination address mismatch");
    require(keccak256(abi.encodePacked(request.txHash)) == keccak256(abi.encodePacked(txHash)), "Tx Hash mismatch");
    request.txHash = txHash;
    is_address_active[request.deposit_address_id] = false;
    request.status = RequestStatus.Released;
    wjxn.transfer(request.to, request.amount - fee);
    emit Release(request_id, request.to, request.amount - fee);
  }

  function get_user_requests(address user) external view returns(uint[] memory) {
    return user_requests[user];
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
    require(isBridgeOperator(msg.sender), "Not a bridge operator");
    operating_limits[operator] = operating_limit;
    emit Set_Operating_Limit(operator, operating_limit);
  }

  function set_fee(uint _fee) external onlyAdmin {
    fee = _fee;
    emit Set_Fee(fee);
  }
}
