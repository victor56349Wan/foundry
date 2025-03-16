// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./BaseScript.s.sol";
import "../src/NFTMarket.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract CounterScript is BaseScript {
    

    function run() public broadcaster {

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        address proxy = Upgrades.deployTransparentProxy(
            "NFTMarket.sol",
            tx.origin,
            //deployer,   // INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            abi.encodeCall(NFTMarket.initialize, (0x895975c2C30cd625D97a051e5E8f6E9c7E464774)),
            opts
            );

        saveContract("local", "Counter", proxy);

        console.log("Counter deployed on %s", address(proxy));
    }
}