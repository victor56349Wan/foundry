// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./BaseScript.s.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract CounterScript is BaseScript {
    

    function run() public broadcaster {

        Options memory opts;
        opts.unsafeSkipAllChecks = true;
        opts.referenceContract = "CounterV1.sol";

        // proxy: 0x613c84B64e51064f86C1584d7C271b7b604bbB93
        Upgrades.upgradeProxy(0x613c84B64e51064f86C1584d7C271b7b604bbB93, "CounterV2.sol", "", opts);

    }
}