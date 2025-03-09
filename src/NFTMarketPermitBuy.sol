// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * 修改Token 购买 NFT NTFMarket 合约，添加功能 permitBuy() 实现只有离线授权的白名单地址才可以购买 NFT （用自己的名称发行 NFT，再上架） 。
 白名单具体实现逻辑为：项目方给白名单地址签名，白名单用户拿到签名信息后，传给 permitBuy() 函数，在permitBuy()中判断时候是经过许可的白名单用户，
 如果是，才可以进行后续购买，否则 revert 。

要求: 
1, 有 Token 存款及 NFT 购买成功的测试用例
2, 有测试用例运行日志或截图，能够看到 Token 及 NFT 转移。
 * 
 */
import "./NFTMarket.sol";

contract NFTMarketPermitBuy is NFTMarket {
    bytes32 public immutable PERMITBUY_TYPEHASH = keccak256("permitBuy(address nftContract, address buyer, uint256 deadline, uint256 tokenId, uint8 v, uint256 r, uint256 s)");
    bytes32 public immutable DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public DOMAIN_SEPARATOR;

    constructor(address _paymentToken) NFTMarket(_paymentToken) {
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("NFTWL")), keccak256(bytes('1')), block.chainid, address(this)));
    }

    function permitBuy(address nftContract, address buyer, uint256 deadline, uint256 tokenId, uint8 v, bytes32 r, bytes32 s) external {
        require(block.timestamp <= deadline, 'expired deadline');

        bytes32 permitBuyStructHash = keccak256(abi.encode(PERMITBUY_TYPEHASH, nftContract, buyer, deadline));
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, permitBuyStructHash));
        
        address owner = IERC721(nftContract).ownerOf(tokenId);
        require(owner == ecrecover(digest, v, r, s), 'invalid signer');
        
        NFTMarket(this).buyNFT(nftContract, tokenId, buyer);
    }
}