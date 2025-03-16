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
    ExtERC20 public defaultToken;    // 重命名为defaultToken以更清晰
    ExtERC20 public customToken;     // 新增的自定义支付代币
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
        defaultToken = new ExtERC20("Default Token", "DTK", 18, 10**6);
        customToken = new ExtERC20("Custom Token", "CTK", 18, 10**6);
        nftToken = new BaseERC721("MockERC721", "MNFT", baseURI);
        nftMarket = new NFTMarket();
        nftMarket.initialize(address(defaultToken));
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

        (address seller, uint256 expectedPrice, bool isActive, ) = nftMarket.getListingDetails(address(nftToken), tokenId);
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
        defaultToken.mint(address(1), price * 2);
        vm.startPrank(address(1));
        defaultToken.approve(address(nftMarket), price);
        vm.expectEmit(true, true, true, true);
        emit NFTMarket.NFTSold(address(nftToken), address(this), address(1), tokenId, price);
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(nftToken.ownerOf(tokenId), address(1));
        vm.stopPrank();

        // 重复购买
        defaultToken.mint(address(2), price * 2);
        vm.startPrank(address(2));
        defaultToken.approve(address(nftMarket), price);
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
        defaultToken.approve(address(nftMarket), price * 2);
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(defaultToken.balanceOf(address(2)), price * 2 - price);
        nftMarket.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        // 支付Token过少
        defaultToken.mint(address(3), price / 2);
        vm.startPrank(address(3));
        defaultToken.approve(address(nftMarket), price / 2);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        vm.stopPrank();
    }

    // 新增测试用例
    function testListAndBuyWithCustomToken() public {
        uint256 price = 100 * 10 ** 18;
        address seller = makeAddr("seller");
        address buyer = makeAddr("buyer");

        // 准备NFT和代币
        nftToken.mint(seller, tokenId);
        customToken.mint(buyer, price);

        vm.startPrank(seller);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price, address(customToken));
        vm.stopPrank();

        vm.startPrank(buyer);
        customToken.approve(address(nftMarket), price);
        nftMarket.buyNFT(address(nftToken), tokenId, buyer);
        vm.stopPrank();

        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(customToken.balanceOf(seller), price);
        assertEq(customToken.balanceOf(buyer), 0);
    }

    // 模糊测试随机价格上架和随机买家购买
    // 模糊测试：测试随机使用 0.01-10000 Token价格上架NFT，并随机使用任意Address购买NFT

    function testFuzzListAndBuyNFT(uint256 price, address buyer) public {
        vm.assume(price >= 10 ** 16 && price <= 10 ** 22); // 0.01 to 10,000 tokens
        vm.assume(buyer != address(0) && buyer != address(this));

        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);

        defaultToken.mint(buyer, price * 2);
        vm.startPrank(buyer);
        defaultToken.approve(address(nftMarket), price);
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
        defaultToken.mint(address(1), price * 10);
        vm.startPrank(address(1));
        defaultToken.approve(address(nftMarket), price * 10);
        assertEq(defaultToken.balanceOf(address(nftMarket)), 0);
        assertEq(nftToken.balanceOf(address(nftMarket)), 0);
        nftMarket.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(defaultToken.balanceOf(address(nftMarket)), 0);
        assertEq(nftToken.balanceOf(address(nftMarket)), 0);
        vm.stopPrank();
    }

    // 测试使用无效代币地址上架
    function testListWithInvalidToken() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        
        // 使用一个EOA地址作为无效代币地址
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("NFTMarket: Invalid payment token");
        nftMarket.list(address(nftToken), tokenId, price, invalidToken);

        // 使用零地址作为无效代币地址
        //vm.expectRevert("NFTMarket: Invalid payment token");
        //nftMarket.list(address(nftToken), tokenId, price, address(0x0));
    }

    // 测试默认代币回退机制
    function testListWithDefaultToken() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(nftMarket), tokenId);
        uint256 origBalance = defaultToken.balanceOf(address(this)); 
        console.log("origBalance:", origBalance);

        // 使用零地址进行上架，应该会使用默认代币
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTListed(address(nftToken), address(this), tokenId, price);
        nftMarket.list(address(nftToken), tokenId, price, address(0));

        // 获取listing信息并验证
        (address seller, uint256 listingPrice, bool isActive, address payToken) = nftMarket.getListingDetails(address(nftToken), tokenId);
        assertEq(seller, address(this));
        assertEq(listingPrice, price);
        assertTrue(isActive);
        assertEq(payToken, address(defaultToken));
        
        // 使用默认代币进行购买测试
        address buyer = makeAddr("buyer");
        defaultToken.mint(buyer, price);
        
        vm.startPrank(buyer);
        defaultToken.approve(address(nftMarket), price);
        nftMarket.buyNFT(address(nftToken), tokenId, buyer);
        vm.stopPrank();

        // 验证交易结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertTrue(defaultToken.balanceOf(seller) >= price);
        assertEq(defaultToken.balanceOf(buyer), 0);
    }
}
