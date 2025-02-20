// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
        counter.increment();
        assertEq(counter.number(), 2);
        address alice = makeAddr("alice");
        console.log('before', alice, alice.balance); // 1000000000000000000
        vm.deal(alice, 1 ether);
        console.log('after', alice, alice.balance); // 1000000000000000000
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
