// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


contract CounterV1 {
    uint256 public number;
    function initialize() public {
        number = 10;
    }
    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number += 1;
    }

    function add(uint i) public {
        number += 1;
    }
}