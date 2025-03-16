// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./BaseScript.s.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract CounterScript is BaseScript {
    

    function run() public broadcaster {

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        address proxy = Upgrades.deployTransparentProxy(
            "CounterV1.sol",
            tx.origin,
            //deployer,   // INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            '', //abi.encodeCall(Counter.initialize, ("arguments for the initialize function")),
            opts
            );

        saveContract("local", "Counter", proxy);

        console.log("Counter deployed on %s", address(proxy));
    }
}