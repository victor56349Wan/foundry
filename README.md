### 可升级的 NFT 市场合约：
- 实现合约的第⼀版本和  [这个挑战](https://decert.me/quests/abdbc346-8314-4394-8f97-8732780602ed "Solidity 实现用 Token 购买 NFT") 的逻辑一致。
- 逻辑合约的第⼆版本，加⼊离线签名上架 NFT 功能⽅法（签名内容：tokenId， 价格），实现⽤户⼀次性使用 setApproveAll 给 NFT 市场合约，每个 NFT 上架时仅需使⽤签名上架。

- 需要部署到测试⽹，并开源到区块链浏览器，在你的Github的 Readme.md 中备注代理合约及两个实现的合约地址。

#### 提交

- proxy contract:
[0x40Ba3A2C2D42fE666d58D9b4cFbc655D00e0bFDd](https://sepolia.etherscan.io/address/0x40Ba3A2C2D42fE666d58D9b4cFbc655D00e0bFDd#code "代码链接")
- nftMarket contract:
[0xFbCF379E5e925eEF530B26FF3440Ab6a94b9cf44](https://sepolia.etherscan.io/address/0xFbCF379E5e925eEF530B26FF3440Ab6a94b9cf44#code "代码链接")
- nftMarketV2 contract:
[0x7fB79b4806C569892E02C27795280E77A44F1446](https://sepolia.etherscan.io/address/0x7fB79b4806C569892E02C27795280E77A44F1446#code "代码链接")
- ERC20 pay token:
[0x70b2Ef5885F0236f26456C6513bA44757586f19a](https://sepolia.etherscan.io/address/0x70b2Ef5885F0236f26456C6513bA44757586f19a#code "代码链接") 
- nft contract:
0x76267fC37D8Ef1d6C27Da0e86D7e5C6c82bc6701