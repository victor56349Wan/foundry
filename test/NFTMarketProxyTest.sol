pragma solidity ^0.8.0;

import "forge-std/Test.sol";
//import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
//import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/NFTMarket.sol";
import "../src/ExtERC20.sol";
import "../src/BaseERC721.sol";

contract NFTMarketProxyTest is Test {
    NFTMarket public implementation;
    address public proxy;
    NFTMarket public market;  // 指向代理的接口
    ExtERC20 public defaultToken;
    ExtERC20 public customToken;
    BaseERC721 public nftToken;
    uint256 public tokenId = 0;
    address public proxyAdmin;
    //ProxyAdmin public admin;

    function setUp() public {
        string memory baseURI = "ipfs://QmdYeDpkVZedk1mkGodjNmF35UNxwafhFLVvsHrWgJoz6A/beanz_metadata";
        defaultToken = new ExtERC20("Default Token", "DTK", 18, 10**6);
        customToken = new ExtERC20("Custom Token", "CTK", 18, 10**6);
        nftToken = new BaseERC721("MockERC721", "MNFT", baseURI);

        // 部署实现合约
        // implementation = new NFTMarket();

        // 部署ProxyAdmin
        // admin = new ProxyAdmin();
        
        // 准备初始化数据
        /**
        bytes memory initData = abi.encodeWithSelector(
            NFTMarket.initialize.selector,
            address(defaultToken)
        );
        */

        bytes memory initData = abi.encodeCall(NFTMarket.initialize, (address(defaultToken)));
        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        proxy = Upgrades.deployTransparentProxy(
            "NFTMarket.sol",
            address(this),
            //deployer,   // INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            initData,
            opts
            );

        // 使用TransparentUpgradeableProxy替代ERC1967Proxy
        /**
        proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(admin),
            initData
        );
         */

        // 获取代理的admin
        proxyAdmin = address(uint160(uint256(vm.load(
            proxy,
            0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
        ))));

        console.log("ProxyAdmin:", proxyAdmin);
        console.log("This:", address(this));
        console.log("msg.sender:", msg.sender);
        console.log("tx.origin:", tx.origin);
        /**
          ProxyAdmin: 0xa38D17ef017A314cCD72b8F199C0e108EF7Ca04c
  This: 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
  msg.sender: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
  tx.origin: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
   */
        
        // 获取代理合约的接口
        market = NFTMarket(address(proxy));
        /**
        upgradeImplementation();
        if directly upgrade to V2, only 1 test case(testBuyNFT()) will fail due to the change of event 
        */
    }

    function testProxyInitialization() public view{
        // 验证代理合约是否正确初始化
        assertEq(address(market.defaultPaymentToken()), address(defaultToken));
    }

    function testListNFTThroughProxy() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTListed(address(nftToken), address(this), tokenId, price);
        market.list(address(nftToken), tokenId, price);

        (address seller, uint256 expectedPrice, bool isActive, address payToken) = market.getListingDetails(address(nftToken), tokenId);
        assertEq(price, expectedPrice);
        assertEq(seller, address(this));
        assertTrue(isActive);
        assertEq(payToken, address(defaultToken));
    }

    function testBuyNFTThroughProxy() public {
        uint256 price = 100 * 10 ** 18;
        address buyer = makeAddr("buyer");
        
        // 上架NFT
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);

        // 购买NFT
        defaultToken.mint(buyer, price);
        vm.startPrank(buyer);
        defaultToken.approve(address(market), price);
        uint256 balanceBefore = defaultToken.balanceOf(address(this));
        market.buyNFT(address(nftToken), tokenId, address(0));
        vm.stopPrank();

        // 验证结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(defaultToken.balanceOf(address(this)) - balanceBefore, price);
        assertEq(defaultToken.balanceOf(buyer), 0);
    }

    function upgradeImplementation() public {
        // 切换到ProxyAdmin所有者
        // vm.startPrank(address(this));

        Options memory opts;
        opts.unsafeSkipAllChecks = true;
        opts.referenceContract = "NFTMarket.sol";

        Upgrades.upgradeProxy(proxy, "NFTMarketV2.sol", "", opts);
        
        // vm.stopPrank();

        // 验证功能是否正常
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);


        (,uint256 listedPrice,,) = market.getListingDetails(address(nftToken), tokenId);
        assertEq(price, listedPrice);
        tokenId += 1;
    }

    // 其他测试用例可以从 NFTMarketTest 中迁移过来
    // 主要区别是使用 market 替代 market 作为合约调用对象
    // ...existing test functions from NFTMarketTest...

  // 测试上架NFT的成功和失败情况

    // 上架NFT：测试上架成功和失败情况，要求断言错误信息和上架事件。
    function testListNFT() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTListed(address(nftToken), address(this), tokenId, price);
        market.list(address(nftToken), tokenId, price);

        (address seller, uint256 expectedPrice, bool isActive, ) = market.getListingDetails(address(nftToken), tokenId);
        assertEq(price, expectedPrice);
        assertEq(seller, address(this));
        assertTrue(isActive);

        // 重复上架
        vm.expectRevert("NFTMarket: Already listed");
        market.list(address(nftToken), tokenId, price);

        // 非所有者上架
        vm.startPrank(address(1));
        vm.expectRevert("NFTMarket: Not the owner");
        market.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        // 零价格上架
        vm.expectRevert("NFTMarket: Price must be greater than zero");
        market.list(address(nftToken), tokenId, 0);
    }

    // 测试购买NFT的成功和失败情况
    // 购买NFT：测试购买成功、自己购买自己的NFT、NFT被重复购买、支付Token过多或者过少情况，要求断言错误信息和购买事件。
    function testBuyNFT() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);

        // 成功购买
        defaultToken.mint(address(1), price * 2);
        vm.startPrank(address(1));
        defaultToken.approve(address(market), price);
        vm.expectEmit(true, true, true, true);
        emit NFTMarket.NFTSold(address(nftToken), address(this), address(1), tokenId, price);

        market.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(nftToken.ownerOf(tokenId), address(1));
        vm.stopPrank();

        // 重复购买
        defaultToken.mint(address(2), price * 2);
        vm.startPrank(address(2));
        defaultToken.approve(address(market), price);
        vm.expectRevert("NFTMarket: Not listed");
        market.buyNFT(address(nftToken), tokenId, address(0));
        vm.stopPrank();

        // 自己购买自己的NFT
        vm.startPrank(address(1));        
        market.list(address(nftToken), tokenId, price);
        nftToken.approve(address(market), tokenId);
        vm.expectRevert("NFTMarket: Seller cannot be buyer");
        market.buyNFT(address(nftToken), tokenId, address(0));
        vm.stopPrank();

        // 支付Token过多
        vm.startPrank( nftToken.ownerOf(tokenId));
        vm.stopPrank();
        vm.startPrank(address(2));
        defaultToken.approve(address(market), price * 2);
        market.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(defaultToken.balanceOf(address(2)), price * 2 - price);
        market.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        // 支付Token过少
        defaultToken.mint(address(3), price / 2);
        vm.startPrank(address(3));
        defaultToken.approve(address(market), price / 2);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        market.buyNFT(address(nftToken), tokenId, address(0));
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
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price, address(customToken));
        vm.stopPrank();

        vm.startPrank(buyer);
        customToken.approve(address(market), price);
        market.buyNFT(address(nftToken), tokenId, buyer);
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
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);

        defaultToken.mint(buyer, price * 2);
        vm.startPrank(buyer);
        defaultToken.approve(address(market), price);
        market.buyNFT(address(nftToken), tokenId, address(0)); // 使用默认买家
        assertEq(nftToken.ownerOf(tokenId), buyer);
        vm.stopPrank();
    }

    // 不可变测试
    //「可选」不可变测试：测试无论如何买卖，NFTMarket合约中都不可能有 Token 持仓
    function testImmutableNFTMarket() public {
        uint256 price = 100 * 10 ** 18;

        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);
        defaultToken.mint(address(1), price * 10);
        vm.startPrank(address(1));
        defaultToken.approve(address(market), price * 10);
        assertEq(defaultToken.balanceOf(address(market)), 0);
        assertEq(nftToken.balanceOf(address(market)), 0);
        market.buyNFT(address(nftToken), tokenId, address(0));
        assertEq(defaultToken.balanceOf(address(market)), 0);
        assertEq(nftToken.balanceOf(address(market)), 0);
        vm.stopPrank();
    }

    // 测试使用无效代币地址上架
    function testListWithInvalidToken() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        
        // 使用一个EOA地址作为无效代币地址
        address invalidToken = makeAddr("invalidToken");
        
        vm.expectRevert("NFTMarket: Invalid payment token");
        market.list(address(nftToken), tokenId, price, invalidToken);

        // 使用零地址作为无效代币地址
        //vm.expectRevert("NFTMarket: Invalid payment token");
        //market.list(address(nftToken), tokenId, price, address(0x0));
    }

    // 测试默认代币回退机制
    function testListWithDefaultToken() public {
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(market), tokenId);
        uint256 origBalance = defaultToken.balanceOf(address(this)); 
        console.log("origBalance:", origBalance);

        // 使用零地址进行上架，应该会使用默认代币
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTListed(address(nftToken), address(this), tokenId, price);
        market.list(address(nftToken), tokenId, price, address(0));

        // 获取listing信息并验证
        (address seller, uint256 listingPrice, bool isActive, address payToken) = market.getListingDetails(address(nftToken), tokenId);
        assertEq(seller, address(this));
        assertEq(listingPrice, price);
        assertTrue(isActive);
        assertEq(payToken, address(defaultToken));
        
        // 使用默认代币进行购买测试
        address buyer = makeAddr("buyer");
        defaultToken.mint(buyer, price);
        
        vm.startPrank(buyer);
        defaultToken.approve(address(market), price);
        market.buyNFT(address(nftToken), tokenId, buyer);
        vm.stopPrank();

        // 验证交易结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertTrue(defaultToken.balanceOf(seller) >= price);
        assertEq(defaultToken.balanceOf(buyer), 0);
    }
}
