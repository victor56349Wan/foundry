// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
编写 NFTMarket 合约：

支持设定任意ERC20价格来上架NFT
支持支付ERC20购买指定的NFT
要求测试内容：

上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT
「可选」不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
*/
import "forge-std/Test.sol";
import "../src/NFTMarket.sol";
import "../src/ExtERC20.sol";
import "../src/BaseERC721.sol";

contract NFTMarketTest is Test, IERC721Receiver {
    NFTMarket public nftMarket;
    ExtERC20 public erc20Token;
    BaseERC721 public nftToken;
    uint256 public tokenId = 0;
    /**
     * @dev 实现IERC721Receiver接口
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setUp() public {
        string memory baseURI = "ipfs://QmdYeDpkVZedk1mkGodjNmF35UNxwafhFLVvsHrWgJoz6A/beanz_metadata";
        erc20Token = new ExtERC20("MockERC20", "MERC20", 18, 10**6);
        nftToken = new BaseERC721("MockERC721", "MNFT", baseURI);
        nftMarket = new NFTMarket(address(erc20Token));
    }

    // 测试上架NFT的成功和失败情况

    // 上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
    function testListNFT() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTListed(address(nftToken), address(this), tokenId, price);
        nftMarket.list(address(nftToken), tokenId, price);

        (address seller, uint256 expectedPrice, bool isActive) = nftMarket.getListingDetails(address(nftToken), tokenId);
        assertEq(price, expectedPrice);
        assertEq(seller, address(this));
        assertTrue(isActive);

        // 重复上架
        vm.expectRevert("NFTMarket: Already listed");
        nftMarket.list(address(nftToken), tokenId, price);

        // 非所有者上架
        vm.startPrank(address(1));
        vm.expectRevert("NFTMarket: Not the owner");
        nftMarket.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        // 零价格上架
        vm.expectRevert("NFTMarket: Price must be greater than zero");
        nftMarket.list(address(nftToken), tokenId, 0);
    }

    // 测试购买NFT的成功和失败情况
    // 购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
    function testBuyNFT() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);

        // 成功购买
        erc20Token.mint(address(1), price * 2);
        vm.startPrank(address(1));
        erc20Token.approve(address(nftMarket), price);
        vm.expectEmit(true, true, true, true);
        emit NFTMarket.NFTSold(address(nftToken), address(this), address(1), tokenId, price);
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(nftToken.ownerOf(tokenId), address(1));
        vm.stopPrank();

        // 重复购买
        erc20Token.mint(address(2), price * 2);
        vm.startPrank(address(2));
        erc20Token.approve(address(nftMarket), price);
        vm.expectRevert("NFTMarket: Not listed");
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        vm.stopPrank();

        // 自己购买自己的NFT
        vm.startPrank(address(1));        
        nftMarket.list(address(nftToken), tokenId, price);
        nftToken.approve(address(nftMarket), tokenId);
        vm.expectRevert("NFTMarket: Seller cannot be buyer");
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        vm.stopPrank();

        // 支付Token过多
        vm.startPrank( nftToken.ownerOf(tokenId));
        vm.stopPrank();
        vm.startPrank(address(2));
        erc20Token.approve(address(nftMarket), price * 2);
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(erc20Token.balanceOf(address(2)), price * 2 - price);
        nftMarket.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        // 支付Token过少
        erc20Token.mint(address(3), price / 2);
        vm.startPrank(address(3));
        erc20Token.approve(address(nftMarket), price / 2);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        vm.stopPrank();
    }
/*
    function testBuyNFTWithSpecifiedBuyer() public {
        uint256 price = 100 * 10 ** 18;
        address buyer = address(999);
        
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);

        // 使用第三方支付代币，但NFT转给指定买家
        address payer = address(888);
        erc20Token.mint(payer, price);
        vm.startPrank(payer);
        erc20Token.approve(address(nftMarket), price);
        
        vm.expectEmit(true, true, true, true);
        emit NFTMarket.NFTSold(address(nftToken), address(this), buyer, tokenId, price);
        nftMarket.buyNFT(address(nftToken), tokenId, buyer);
        
        assertEq(nftToken.ownerOf(tokenId), buyer);
        vm.stopPrank();
    }
    */

    // 模糊测试随机价格上架和随机买家购买
    // 模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT

    function testFuzzListAndBuyNFT(uint256 price, address buyer) public {
        vm.assume(price >= 10 ** 16 && price <= 10 ** 22); // 0.01 to 10,000 tokens
        vm.assume(buyer != address(0) && buyer != address(this));

        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);

        erc20Token.mint(buyer, price * 2);
        vm.startPrank(buyer);
        erc20Token.approve(address(nftMarket), price);
        nftMarket.buyNFT(address(nftToken), tokenId, address(0)); // 使用默认买家
        assertEq(nftToken.ownerOf(tokenId), buyer);
        vm.stopPrank();
    }

    // 不可变测试
    //「可选」不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
    function testImmutableNFTMarket() public {
        uint256 price = 100 * 10 ** 18;

        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);
        erc20Token.mint(address(1), price * 10);
        vm.startPrank(address(1));
        erc20Token.approve(address(nftMarket), price * 10);
        assertEq(erc20Token.balanceOf(address(nftMarket)), 0);
        assertEq(nftToken.balanceOf(address(nftMarket)), 0);
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(erc20Token.balanceOf(address(nftMarket)), 0);
        assertEq(nftToken.balanceOf(address(nftMarket)), 0);
        vm.stopPrank();
    }
}
