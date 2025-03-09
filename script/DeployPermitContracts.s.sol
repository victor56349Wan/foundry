// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/erc20Permit.sol";
import "../src/tokenBankWithPermitDeposit.sol";
import "../src/NFTMarketPermitBuy.sol";
import "../src/BaseERC721.sol";

contract DeployPermitContracts is Script {
    function run() external {
        // 开始广播交易
        vm.startBroadcast();

        // 1. 部署支付代币(ERC20Permit)
        ERC20Permit paymentToken = new ERC20Permit(
            "Payment Token",
            "PAY",
            18,
            1000000 * 10**18  // 初始供应量 1,000,000
        );
        console.log("ERC20Permit deployed to:", address(paymentToken));

        // 2. 部署TokenBank合约
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = address(paymentToken);
        TokenBankPermitDeposit bank = new TokenBankPermitDeposit(supportedTokens);
        console.log("TokenBankPermitDeposit deployed to:", address(bank));

        // 3. 部署NFT合约(用于NFTMarket测试)
        string memory baseURI = "ipfs://QmdYeDpkVZedk1mkGodjNmF35UNxwafhFLVvsHrWgJoz6A/";
        BaseERC721 nft = new BaseERC721(
            "Victor Demo NFT",
            "VDNFT",
            baseURI
        );
        console.log("BaseERC721 deployed to:", address(nft));

        // 4. 部署NFTMarket合约
        NFTMarketPermitBuy market = new NFTMarketPermitBuy(address(paymentToken));
        console.log("NFTMarketPermitBuy deployed to:", address(market));

        vm.stopBroadcast();
    }
}
