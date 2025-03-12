// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/NFTMarketV1.sol";
import "../src/NFTMarketV2.sol";

contract DeployNFTMarket is Script {
    address public proxyAdmin;
    address public defaultPaymentToken = 0xYourDefaultTokenAddress; // 替换为实际代币地址

    function run() external {
        vm.startBroadcast();

        // 部署 V1 实现
        NFTMarketV1 v1 = new NFTMarketV1(defaultPaymentToken);
        console.log("V1 Implementation deployed at:", address(v1));

        // 部署代理管理员（ProxyAdmin）
        ProxyAdmin admin = new ProxyAdmin();
        proxyAdmin = address(admin);
        console.log("ProxyAdmin deployed at:", proxyAdmin);

        // 部署透明代理，指向 V1
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(v1),
            proxyAdmin,
            abi.encodeWithSignature("constructor(address)", defaultPaymentToken)
        );
        console.log("Proxy deployed at:", address(proxy));

        // 部署 V2 实现
        NFTMarketV2 v2 = new NFTMarketV2(defaultPaymentToken);
        console.log("V2 Implementation deployed at:", address(v2));

        // 升级到 V2
        ProxyAdmin(proxyAdmin).upgrade(address(proxy), address(v2));
        console.log("Upgraded to V2 at:", address(v2));

        vm.stopBroadcast();
    }
}