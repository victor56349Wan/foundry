// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
/**
为银行合约的 DepositETH 方法编写测试 Case，检查以下内容：

断言检查 Deposit 事件输出是否符合预期。
断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
要求：直接提交完整的 BankTest.sol 测试合约源代码。
*/
import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";


contract BankTest is Test {
    Bank public bank;
    address public user;
    uint256 public depositAmount;

    // 在每个测试用例执行前设置测试环境
    function setUp() public {
        bank = new Bank();  // 部署新的Bank合约
        user = address(1);  // 设置测试用户地址
        depositAmount = 1 ether;  // 设置存款金额
        vm.deal(user, depositAmount);  // 给测试用户一些ETH 
    }

    // 测试Deposit事件是否正确触发
    function testDepositEvent() public {
        // 以user身份执行存款操作
        vm.prank(user);
        vm.deal(user, depositAmount);  // 给测试用户一些ETH 
        // 期望触发Deposit事件，并验证事件参数
        vm.expectEmit(true, false, false, true);
        emit Bank.Deposit(user, depositAmount);
        
        // 执行存款
        bank.depositETH{value: depositAmount}();
    }

    // 测试存款前后余额变化
    function testDepositBalance() public {
        // 记录存款前的余额
        uint256 balanceBefore = bank.balanceOf(user);
        
        // 以user身份执行存款
        vm.prank(user);
        vm.deal(user, depositAmount);  // 给测试用户一些ETH 
        bank.depositETH{value: depositAmount}();
        
        // 验证存款后的余额是否正确增加
        uint256 balanceAfter = bank.balanceOf(user);
        assertEq(balanceAfter, balanceBefore + depositAmount, "Balance not updated correctly");
    }

    // 测试存款金额为0时是否正确回滚
    function testZeroDepositRevert() public {
        vm.prank(user);
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.depositETH{value: 0}();
    }

    // 测试多次存款的累计金额
    function testMultipleDeposits() public {
        // 第一次存款
        vm.prank(user);
        vm.deal(user, depositAmount);  // 给测试用户一些ETH 
        console.log('before deposit', user, user.balance); // 1000000000000000000
        bank.depositETH{value: depositAmount}();
        console.log('after 1st deposit', user, user.balance); // 1000000000000000000
        
        // 第二次存款
        vm.prank(user);
        vm.deal(user, depositAmount);  // 给测试用户一些ETH 
        bank.depositETH{value: depositAmount}();
        
        console.log('after 2nd deposit', user, user.balance); // 1000000000000000000
        // 验证累计金额是否正确
        assertEq(bank.balanceOf(user), depositAmount * 2, "Multiple deposits not accumulated correctly");
    }

    // 测试不同用户的存款是否正确隔离
    function testMultipleUsersDeposit() public {
        address user2 = address(2);
        vm.deal(user2, depositAmount);

        // user1 存款
        vm.prank(user);
        bank.depositETH{value: depositAmount}();

        // user2 存款
        vm.prank(user2);
        bank.depositETH{value: depositAmount}();

        // 验证两个用户的余额是否正确且相互独立
        assertEq(bank.balanceOf(user), depositAmount, "User1 balance incorrect");
        assertEq(bank.balanceOf(user2), depositAmount, "User2 balance incorrect");
    }
}
