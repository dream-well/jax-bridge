// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract JaxBridgeV2 {

  uint chainId;
  
  uint public fee = 50;

  address public admin;

  address public fee_wallet;

  IERC20 public wjxn = IERC20(0xA25946ec9D37dD826BbE0cbDbb2d79E69834e41e);

  enum RequestStatus {Init, Proved, Rejected, Expired, Released}

  struct Request {
    uint deposit_address_id;
    uint amount;
    bytes32 amount_hash;
    bytes32 txdHash;
    uint valid_until;
    uint prove_timestamp;
    address to;
    RequestStatus status;
    string from;
    string txHash;
  }

  string[] public deposit_addresses;
  uint[] public deposit_address_locktimes;
  mapping(uint => bool) public deposit_address_deleted;

  Request[] public requests;

  mapping(address => uint[]) public user_requests;

  address[] public bridge_operators;
  mapping(address => uint) operating_limits;

  mapping(bytes32 => bool) proccessed_txd_hashes;

  event Create_Request(
    uint request_id,
    bytes32 amount_hash,
    string from,
    uint depoist_address_id,
    uint valid_until
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

  event Free_Deposit_Address(
    uint deposit_address_id
  );

  event Set_Fee_Wallet(
    address wallet
  );

  event Set_Admin(
    address admin
  );

  event Delete_Deposit_Addresses(
    uint[] ids
  );

  constructor() {
    admin = msg.sender;
    uint _chainId;
    assembly {
        _chainId := chainid()
    }
    chainId = _chainId;
    fee_wallet = msg.sender;
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

  modifier isValidDepositAddress(uint deposit_address_id) {
    require(deposit_address_deleted[deposit_address_id] == false, "Deposit address deleted");
    _;
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
      deposit_address_locktimes.push(0);
    }
  }

  function get_free_deposit_address_id() external view returns(uint) {
    for(uint i = 0; i < deposit_address_locktimes.length; i += 1) {
      if(deposit_address_locktimes[i] == 0) return i;
    }
    revert("All deposit addresses are in use");
  }

  function create_request(uint request_id, bytes32 amount_hash, uint deposit_address_id, address to, string calldata from) external {
    require(request_id == requests.length, "Invalid request id");
    Request memory request;
    request.amount_hash = amount_hash;
    request.to = to;
    request.from = from;

    require(deposit_address_locktimes.length > deposit_address_id, "deposit_address_id out of index");
    require(deposit_address_locktimes[deposit_address_id] == 0, "Deposit address is in use");
    request.deposit_address_id = deposit_address_id;
    uint valid_until = block.timestamp + 48 hours;
    request.valid_until = valid_until;
    deposit_address_locktimes[deposit_address_id] = valid_until;
    requests.push(request);
    user_requests[to].push(request_id);
    emit Create_Request(request_id, amount_hash, from, deposit_address_id, valid_until);
  }

  function prove_request(uint request_id, bytes32 txdHash) external {
    Request storage request = requests[request_id];
    require(request.to == msg.sender, "Invalid account");
    require(request.status == RequestStatus.Init, "Invalid status");
    require(request.valid_until >= block.timestamp, "Expired");
    require(proccessed_txd_hashes[txdHash] == false, "Invalid txd hash");
    request.txdHash = txdHash;
    request.status = RequestStatus.Proved;
    request.prove_timestamp = block.timestamp;
    emit Prove_Request(request_id);
  }

  function reject_request(uint request_id) external onlyAdmin {
    Request storage request = requests[request_id];
    require(request.status == RequestStatus.Init || request.status == RequestStatus.Proved, "Invalid status");
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
    require(request.status == RequestStatus.Proved, "Invalid status");
    require(request.txdHash == keccak256(abi.encodePacked(txHash)), "Invalid txHash");
    require(proccessed_txd_hashes[request.txdHash] == false, "Txd hash already processed");
    require(request.amount_hash == keccak256(abi.encodePacked(request_id, amount)), "Incorrect amount");
    require(keccak256(abi.encodePacked(request.from)) == keccak256(abi.encodePacked(from)), "Sender's address mismatch");
    require(request.to == to, "destination address mismatch");
    require(keccak256(abi.encodePacked(request.txHash)) == keccak256(abi.encodePacked(txHash)), "Tx Hash mismatch");
    request.txHash = txHash;
    deposit_address_locktimes[request.deposit_address_id] = 0;
    request.amount = amount;
    request.status = RequestStatus.Released;
    proccessed_txd_hashes[request.txdHash] = true;
    wjxn.transfer(request.to, request.amount - fee);
    wjxn.transfer(fee_wallet, fee);
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
    require(isBridgeOperator(operator), "Not a bridge operator");
    operating_limits[operator] = operating_limit;
    emit Set_Operating_Limit(operator, operating_limit);
  }

  function set_fee(uint _fee) external onlyAdmin {
    fee = _fee;
    emit Set_Fee(fee);
  }

  function free_deposit_addresses() external onlyAdmin  {
    for(uint i = 0; i < deposit_address_locktimes.length; i += 1) {
      if(deposit_address_locktimes[i] < block.timestamp) {
        deposit_address_locktimes[i] = 0;
        emit Free_Deposit_Address(i);
      }
    }
  }

  function delete_deposit_addresses(uint[] calldata ids) external onlyAdmin {
    uint id;
    for(uint i = 0; i < ids.length; i += 1) {
      id = ids[i];
      deposit_address_deleted[id] = true;
    }
    emit Delete_Deposit_Addresses(ids);
  }

  function set_fee_wallet(address _fee_wallet) external onlyAdmin {
    fee_wallet = _fee_wallet;
    emit Set_Fee_Wallet(_fee_wallet);
  }

  function set_admin(address _admin) external onlyAdmin {
    admin = _admin;
    emit Set_Admin(_admin);
  }

  function get_new_request_id() external view returns(uint) {
    return requests.length;
  }
}
