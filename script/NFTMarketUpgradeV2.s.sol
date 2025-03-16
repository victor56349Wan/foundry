// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./BaseScript.s.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";


contract NftMarketScript is BaseScript {
    

    function run() public broadcaster {

        Options memory opts;
        opts.unsafeSkipAllChecks = true;
        opts.referenceContract = "NFTMarket.sol";

        /* proxy: 0xAe53866188484444cf5FD535ed84685BcC67b5e1
        0x351fF0e14a91F76f82e71D1ca068a670b9ba2Af2
        0xf46323b11b0A1865E25f4E4DE258E0C5cCD023d1
        */
        Upgrades.upgradeProxy(0x40Ba3A2C2D42fE666d58D9b4cFbc655D00e0bFDd, "NFTMarketV2.sol", "", opts);

    }
}