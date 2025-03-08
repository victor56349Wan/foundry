// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/erc20WithFee.sol";

contract ERC20WithFeeTest is Test {
    ERC20WithFee token;
    address owner;
    address recipient;

    function setUp() public {
        owner = address(0x123);
        recipient = address(0x456);
        token = new ERC20WithFee("TestToken", "TTK", 18, 1000 ether, 10); // 手续费为1%
        token.transfer(owner, 500 ether);
    }

    function testTransferWithFee() public {
        uint256 amount = 100 ether;
        uint256 fee = (amount * 10) / 1000;
        uint256 amountAfterFee = amount - fee;

        vm.prank(owner);
        console.log("before owner", token.balanceOf(owner));
        console.log("recipient", token.balanceOf(recipient));
        uint256 balance = token.balanceOf(address(token));
        console.log("token contract: ", token.balanceOf(address(token)));
        token.transfer(recipient, amount);
        console.log("after owner", token.balanceOf(owner));
        console.log("recipient", token.balanceOf(recipient));
        assertEq(token.balanceOf(recipient), amountAfterFee);
        assertEq(token.balanceOf(address(token)) - balance, fee);
    }
}