// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./BaseScript.s.sol";
import "../src/NFTMarket.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract NftMarketScript is BaseScript {
    

    function run() public broadcaster {

        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        address defaultToken = address(0x70b2Ef5885F0236f26456C6513bA44757586f19a);
        bytes memory initData = abi.encodeCall(NFTMarket.initialize, (address(defaultToken)));


        address proxy = Upgrades.deployTransparentProxy(
            "NFTMarket.sol",
            //tx.origin,
            msg.sender,
            //deployer,   // INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            initData, 
            opts
            );

        console.log("Counter deployed on %s", address(proxy));
    }
}