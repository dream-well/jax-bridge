// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract JaxBridgeV2 {

  uint chainId;
  
  address public admin;

  IERC20 public wjxn = IERC20(0xA25946ec9D37dD826BbE0cbDbb2d79E69834e41e);

  enum RequestStatus {Init, Approved, Rejected, Released}

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

  event Create_Request(
    uint request_id,
    uint amount,
    string from
  );

  event Approve_Request(
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
    emit Create_Request(request_id, amount, from);
  }

  function approve_request(uint request_id) external onlyAdmin {
    Request storage request = requests[request_id];
    require(request.status == RequestStatus.Init, "Invalid status");
    uint i = 0;
    for(; i <= deposit_addresses.length; i += 1) {
      if(!is_address_active[i])
        break;
    }
    require(i < deposit_addresses.length, "All deposit addresses are active");
    is_address_active[i] = true;
    request.deposit_address_id = i;
    request.valid_until = block.timestamp + 48 hours;
    request.status == RequestStatus.Approved;
    emit Approve_Request(request_id);
  }

  function reject_request(uint request_id) external onlyAdmin {
    Request storage request = requests[request_id];
    require(request.status == RequestStatus.Init, "Invalid status");
    request.status = RequestStatus.Rejected;
    emit Reject_Request(request_id);
  }

  function release(
    uint request_id,
    string calldata txHash
  ) external onlyAdmin {
    Request storage request = requests[request_id];
    request.txHash = txHash;
    is_address_active[request.deposit_address_id] = false;
    request.status = RequestStatus.Released;
    wjxn.transfer(request.to, request.amount - 50);
    emit Release(request_id, request.to, request.amount - 50);
  }

  function get_user_requests(address user) external view returns(uint[] memory) {
    return user_requests[user];
  }

  function withdrawByAdmin(address token, uint amount) external onlyAdmin {
      IERC20(token).transfer(msg.sender, amount);
  }

}
