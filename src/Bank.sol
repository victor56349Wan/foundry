// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
/**
为银行合约的 DepositETH 方法编写测试 Case，检查以下内容：

断言检查 Deposit 事件输出是否符合预期。
断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
要求：直接提交完整的 BankTest.sol 测试合约源代码。
*/
contract Bank {
    mapping(address => uint) public balanceOf;

    event Deposit(address indexed user, uint amount);

    function depositETH() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}