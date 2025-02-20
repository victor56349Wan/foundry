// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external {
        // 从环境变量获取私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 开始使用私钥签名的交易
        vm.startBroadcast(deployerPrivateKey);

        // 部署合约
        MyToken token = new MyToken("Victor Token", "VTK");

        // 结束广播
        vm.stopBroadcast();

        // 输出部署的合约地址
        console.log("Token deployed to:", address(token));
    }
}
