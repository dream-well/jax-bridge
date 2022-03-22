// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./JaxBridge.sol";

contract JaxBridgeETH is JaxBridge {

  constructor() JaxBridge() {
    wjxn = IERC20(0xA25946ec9D37dD826BbE0cbDbb2d79E69834e41e);
    fee = 0.004 ether;
    fee_wallet = 0x5c2661B0060e5769f746e57782028C60cbC3b269;
    verifier = 0x1bd064492b431df3b17e341dfc21a31bbA9CeBCF;
  }
}
