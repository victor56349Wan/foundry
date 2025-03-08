// SPDX-License-Identifier: MIT
/*编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

TokenBank 有两个方法：

deposit() : 需要记录每个地址的存入数量；
withdraw（）: 用户可以提取自己的之前存入的 token。
*/

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;
contract TokenBank {
    // Mapping to track the deposit balance for each address and each token
    mapping(address => mapping(address => uint256)) public balances; // user => token => amount
    // Optional: Track supported tokens (if you want to restrict to specific tokens)
    mapping(address => bool) public supportedTokens;

    // Event declarations for tracking deposits and withdrawals
    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    // Constructor (optional: initialize with supported tokens)
    constructor(address[] memory _initialTokens) {
        for (uint256 i = 0; i < _initialTokens.length; i++) {
            require(_initialTokens[i] != address(0), "Invalid token address");
            supportedTokens[_initialTokens[i]] = true;
        }
    }

    // Deposit function: Supports multiple ERC-20 tokens
    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        // Optional: Check if token is supported (remove this if all ERC-20s are allowed)
        require(supportedTokens[token], "Token not supported");

        uint256 balance = IERC20(token).balanceOf(msg.sender);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        require(balance - amount == IERC20(token).balanceOf(msg.sender), 'Balance NOT add up');
        balances[msg.sender][token] += amount;

        emit Deposited(msg.sender, token, amount);
    }

    // Withdraw function: Withdraw a specific amount of a specific token deposit by sender
    function withdraw(address token, uint256 amount) external {
        uint256 balanceInBank = balances[msg.sender][token];
        require(balanceInBank >= amount, "Insufficient balance");

        uint256 balance = IERC20(token).balanceOf(msg.sender);
        IERC20(token).safeTransfer(msg.sender, amount);
        require(IERC20(token).balanceOf(msg.sender)  == amount + balance , 'Balance NOT add up');

        balances[msg.sender][token] -= amount;
        emit Withdrawn(msg.sender, token, amount);
    }


    // WithdrawAll function: Withdraw all of a specific token deposit by sender
    function withdrawAll(address token) external {
        uint256 amount = balances[msg.sender][token];
        require(amount > 0, "Insufficient balance");

        uint256 balance = IERC20(token).balanceOf(msg.sender);        
        IERC20(token).safeTransfer(msg.sender, amount);
        require(IERC20(token).balanceOf(msg.sender)  == amount + balance , 'Balance NOT add up');
        balances[msg.sender][token] = 0;
        
        emit Withdrawn(msg.sender, token, amount);
    }

    // Optional: Add a supported token (only for restricted mode)
    // TODO:: to add owner modifier for this method
    function addSupportedToken(address token) external {
        require(token != address(0), "Invalid token address");
        require(!supportedTokens[token], "Token already supported");
        supportedTokens[token] = true;
    }

    // Query balance for a specific user and token
    function getBalance(address user, address token) external view returns (uint256) {
        return balances[user][token];
    }
}