// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./BaseScript.s.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract CounterScript is BaseScript {
    

    function run() public broadcaster {

        Options memory opts;
        opts.unsafeSkipAllChecks = true;
        opts.referenceContract = "NFTMarket.sol";

        // proxy: 0x918a35269bFFb412DB8F5b6e2733717Cd900BDa4
        Upgrades.upgradeProxy(0x918a35269bFFb412DB8F5b6e2733717Cd900BDa4, "NFTMarketV2.sol", "", opts);

    }
}