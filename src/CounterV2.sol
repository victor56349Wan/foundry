// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;



contract CounterV2 {
    uint256 public magic = 55;
    uint256 public number = 11;
    uint8 public version = 2;
    uint8 public dummy = 2;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }
    function setVersion(uint8 newVersion) public {
        version = newVersion;
    }
    function add(uint i) public {
        number += i;
    }
}