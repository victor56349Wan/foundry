// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external {
        // 从环境变量获取私钥
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 开始使用私钥签名的交易
        //vm.startBroadcast(deployerPrivateKey);
        vm.startBroadcast();

        // 部署合约
        MyToken token = new MyToken("Victor Token", "VTK");

        // 结束广播
        vm.stopBroadcast();

        // 输出部署的合约地址
        console.log("Token deployed to:", address(token));
    }
}
/** cmd result
$ forge script script/DeployMyToken.s.sol:DeployMyToken --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
[⠒] Compiling...
[⠒] Compiling 1 files with Solc 0.8.25
[⠢] Solc 0.8.25 finished in 927.06ms
Compiler run successful!
^@Traces:
  [1040698] DeployMyToken::run()
    ├─ [0] VM::envUint("PRIVATE_KEY") [staticcall]
    │   └─ ← [Return] <env var value>
    ├─ [0] VM::startBroadcast(<pk>)
    │   └─ ← [Return]
    ├─ [998762] → new MyToken@0x7CC71121FB38265fC9e34a144565A147C580a014
    │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x8527938232C7d36A37DcBc0e711b67f2F55eE7d5, value: 10000000000000000000000000000 [1e28])
    │   └─ ← [Return] 4521 bytes of code
    ├─ [0] VM::stopBroadcast()
    │   └─ ← [Return]
    ├─ [0] console::log("Token deployed to:", MyToken: [0x7CC71121FB38265fC9e34a144565A147C580a014]) [staticcall]
    │   └─ ← [Stop]
    └─ ← [Stop]


Script ran successfully.

== Logs ==
  Token deployed to: 0x7CC71121FB38265fC9e34a144565A147C580a014

## Setting up 1 EVM.
==========================
Simulated On-chain Traces:

  [998762] → new MyToken@0x7CC71121FB38265fC9e34a144565A147C580a014
    ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x8527938232C7d36A37DcBc0e711b67f2F55eE7d5, value: 10000000000000000000000000000 [1e28])
    └─ ← [Return] 4521 bytes of code


==========================

Chain 11155111

Estimated gas price: 3.523856683 gwei

Estimated total gas used for script: 1494467

Estimated amount required: 0.005266287525472961 ETH

==========================

##### sepolia
✅  [Success] Hash: 0xd749fc74d2238d8cadf563015b941bac058511aa0665e1eb86165cad135b53b8
Contract Address: 0x7CC71121FB38265fC9e34a144565A147C580a014
Block: 7749187
Paid: 0.00199682045624633 ETH (1149590 gas * 1.736984887 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.00199682045624633 ETH (1149590 gas * avg 1.736984887 gwei)


==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
##
Start verification for (1) contracts
Start verifying contract `0x7CC71121FB38265fC9e34a144565A147C580a014` deployed on sepolia
Compiler version: 0.8.25
Constructor args: 00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000c566963746f7220546f6b656e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000356544b0000000000000000000000000000000000000000000000000000000000

Submitting verification for [src/MyToken.sol:MyToken] 0x7CC71121FB38265fC9e34a144565A147C580a014.
Submitted contract for verification:
	Response: `OK`
	GUID: `xdguzi2aykt7eygdsnchuwgezyy6ri5bkkgavpjp1zemesmjnj`
	URL: https://sepolia.etherscan.io/address/0x7cc71121fb38265fc9e34a144565a147c580a014
Contract verification status:
Response: `NOTOK`
Details: `Pending in queue`
Warning: Verification is still pending...; waiting 15 seconds before trying again (7 tries remaining)
Contract verification status:
Response: `OK`
Details: `Pass - Verified`
Contract successfully verified
All (1) contracts were verified!

Transactions saved to: /Users/zfu/MyDev/forDemo/hello_foundry/broadcast/DeployMyToken.s.sol/11155111/run-latest.json

Sensitive values saved to: /Users/zfu/MyDev/forDemo/hello_foundry/cache/DeployMyToken.s.sol/11155111/run-latest.json*/