// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "./JaxBridge.sol";

contract JaxBridgeBSC is JaxBridge {

  constructor() JaxBridge() {
    wjxn = IERC20(0xcA1262e77Fb25c0a4112CFc9bad3ff54F617f2e6);
    fee = 0.25 ether;
    fee_wallet = 0x5c2661B0060e5769f746e57782028C60cbC3b269;
    verifier = 0x1bd064492b431df3b17e341dfc21a31bbA9CeBCF;
  }
}
