// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenB is ERC20 {
    constructor() ERC20("Token B", "TKB") {
        _mint(msg.sender, 1_000_000 * 10**18); // 1M tokens
    }
}