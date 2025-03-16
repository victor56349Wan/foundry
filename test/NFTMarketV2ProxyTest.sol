pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "../src/ExtERC20.sol";
import "../src/BaseERC721.sol";
import "../src/NFTMarket.sol";
import "../src/NFTMarketV2.sol";
contract NFTMarketV2ProxyTest is Test {
    NFTMarket public implementation;
    address public proxy;
    NFTMarketV2 public v2Market;  // 指向代理的接口
    ExtERC20 public defaultToken;
    ExtERC20 public customToken;
    BaseERC721 public nftToken;
    uint256 public tokenId = 0;
    address public proxyAdmin;
    //ProxyAdmin public admin;

    uint256 sellerPrivateKey;
    address seller;



    function setUp() public {
        string memory baseURI = "ipfs://QmdYeDpkVZedk1mkGodjNmF35UNxwafhFLVvsHrWgJoz6A/beanz_metadata";
        defaultToken = new ExtERC20("Default Token", "DTK", 18, 10**6);
        customToken = new ExtERC20("Custom Token", "CTK", 18, 10**6);
        nftToken = new BaseERC721("MockERC721", "MNFT", baseURI);

        // 新建V2市场合约
        v2Market = new NFTMarketV2();
        v2Market.initialize(address(defaultToken));
        // 创建卖家账户
        (seller, sellerPrivateKey) = makeAddrAndKey("seller");

        bytes memory initData = abi.encodeCall(NFTMarket.initialize, (address(defaultToken)));
        Options memory opts;
        opts.unsafeSkipAllChecks = true;

        proxy = Upgrades.deployTransparentProxy(
            "NFTMarket.sol",
            address(this),  // INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            initData,
            opts
            );

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
        /**
        if directly upgrade to V2, only 1 test case(testBuyNFT()) will fail 
            due to the change of event, need to use NFMarketV2 instead of NFTMarket
        */
        upgradeImplementation();

    }

    function testProxyInitialization() public view{
        // 验证代理合约是否正确初始化
        assertEq(address(v2Market.defaultPaymentToken()), address(defaultToken));
    }


    function upgradeImplementation() public {
        // 切换到ProxyAdmin所有者
        // vm.startPrank(address(this));

        Options memory opts;
        opts.unsafeSkipAllChecks = true;
        opts.referenceContract = "NFTMarket.sol";

        Upgrades.upgradeProxy(proxy, "NFTMarketV2.sol", "", opts);
        
        // vm.stopPrank();

        // 获取代理合约的接口
        v2Market = NFTMarketV2(address(proxy));
        // 验证功能是否正常
        uint256 price = 100 * 10 ** 18;
        nftToken.mint(address(this), tokenId);
        nftToken.approve(address(v2Market), tokenId);
        v2Market.list(address(nftToken), tokenId, price);






        (,uint256 listedPrice,,) = v2Market.getListingDetails(address(nftToken), tokenId);
        assertEq(price, listedPrice);
        tokenId += 1;
 
    }

    // 其他测试用例可以从 NFTMarketTest 中迁移过来
    // 主要区别是使用 market 替代 market 作为合约调用对象
    // ...existing test functions from NFTMarketTest...


    function testBuyNFTWithSignature() public {
        uint256 price = 100 * 10 ** 18;
        address buyer = makeAddr("buyer");
        uint256 deadline = block.timestamp + 1 days;

        // 准备NFT和代币
        nftToken.mint(seller, tokenId);
        defaultToken.mint(buyer, price);

        // 卖家授权NFT
        vm.startPrank(seller);
        nftToken.approve(address(v2Market), tokenId);
        vm.stopPrank();

        // 准备签名数据
        NFTMarketV2.Listing memory listing = NFTMarketV2.Listing({
            nftContract: address(nftToken),
            tokenId: tokenId,
            seller: seller,
            payToken: address(defaultToken),
            price: price,
            isActive: true
        });

        bytes32 structHash = keccak256(abi.encode(
            v2Market.BUYNFT_TYPEHASH(),
            listing.nftContract,
            listing.tokenId,
            listing.seller,
            listing.payToken,
            listing.price,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            v2Market.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        // 买家授权和购买
        vm.startPrank(buyer);
        defaultToken.approve(address(v2Market), price);
        v2Market.buyNFT(listing, buyer, deadline, v, r, s);
        vm.stopPrank();

        // 验证结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(defaultToken.balanceOf(seller), price);
        assertEq(defaultToken.balanceOf(buyer), 0);
    }

    function testBuyNFTWithExpiredSignature() public {
        uint256 price = 100 * 10 ** 18;
        address buyer = makeAddr("buyer");
        //uint256 tokenId = 1;
        uint256 deadline = block.timestamp + 1 days;

        // 设置NFT和上架
        nftToken.mint(seller, tokenId);
        vm.prank(seller);
        nftToken.approve(address(v2Market), tokenId);
        vm.prank(seller);

        NFTMarketV2.Listing memory listing = NFTMarketV2.Listing({
            nftContract: address(nftToken),
            tokenId: tokenId,
            seller: seller,
            payToken: address(defaultToken),
            price: price,
            isActive: true
        });

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            v2Market.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                v2Market.BUYNFT_TYPEHASH(),
                listing.nftContract,
                listing.tokenId,
                listing.seller,
                listing.payToken,
                listing.price,
                deadline
            ))
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        // 时间前进到deadline之后
        vm.warp(deadline + 1);

        vm.expectRevert("Expired deadline");
        v2Market.buyNFT(listing, buyer, deadline, v, r, s);
    }

    function testBuyNFTWithInvalidSignature() public {
        uint256 price = 100 * 10 ** 18;
        address buyer = makeAddr("buyer");
        //uint256 tokenId = 1;
        uint256 deadline = block.timestamp + 1 days;

        // 设置NFT和上架
        nftToken.mint(seller, tokenId);
        vm.prank(seller);
        nftToken.approve(address(v2Market), tokenId);
        vm.prank(seller);
        

        NFTMarketV2.Listing memory listing = NFTMarketV2.Listing({
            nftContract: address(nftToken),
            tokenId: tokenId,
            seller: seller,
            payToken: address(defaultToken),
            price: price,
            isActive: true
        });

        // 使用错误的私钥签名
        (,uint256 wrongPrivateKey) = makeAddrAndKey("wrong");
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            v2Market.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                v2Market.BUYNFT_TYPEHASH(),
                listing.nftContract,
                listing.tokenId,
                listing.seller,
                listing.payToken,
                listing.price,
                deadline
            ))
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);

        vm.expectRevert("NFTMarket: Invalid signature");
        v2Market.buyNFT(listing, buyer, deadline, v, r, s);
    }

    function testBuyNFTWithThirdParty() public {
        uint256 price = 100 * 10 ** 18;
        address buyer = makeAddr("buyer");
        address thirdParty = makeAddr("thirdParty");
        //uint256 tokenId = 1;
        uint256 deadline = block.timestamp + 1 days;

        // 准备NFT和代币
        nftToken.mint(seller, tokenId);
        defaultToken.mint(buyer, price);

        // 卖家上架
        vm.startPrank(seller);
        nftToken.approve(address(v2Market), tokenId);
        vm.stopPrank();

        NFTMarketV2.Listing memory listing = NFTMarketV2.Listing({
            nftContract: address(nftToken),
            tokenId: tokenId,
            seller: seller,
            payToken: address(defaultToken),
            price: price,
            isActive: true
        });

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            v2Market.DOMAIN_SEPARATOR(),
            keccak256(abi.encode(
                v2Market.BUYNFT_TYPEHASH(),
                listing.nftContract,
                listing.tokenId,
                listing.seller,
                listing.payToken,
                listing.price,
                deadline
            ))
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        // 买家授权代币
        vm.prank(buyer);
        defaultToken.approve(address(v2Market), price);

        // 第三方提交交易
        vm.prank(thirdParty);
        v2Market.buyNFT(listing, buyer, deadline, v, r, s);

        // 验证结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(defaultToken.balanceOf(seller), price);
        assertEq(defaultToken.balanceOf(buyer), 0);
        assertEq(defaultToken.balanceOf(thirdParty), 0);
    }

    function testPreventSignatureReplay() public {
        uint256 price = 100 * 10 ** 18;
        address buyer = makeAddr("buyer");
        //uint256 tokenId = 1;
        uint256 deadline = block.timestamp + 1 days;

        // 准备NFT和代币
        nftToken.mint(seller, tokenId);
        defaultToken.mint(buyer, price * 2); // 铸造足够多的代币供两次购买

        // 卖家上架NFT
        vm.startPrank(seller);
        nftToken.approve(address(v2Market), tokenId);
        vm.stopPrank();

        // 准备签名数据
        NFTMarketV2.Listing memory listing = NFTMarketV2.Listing({
            nftContract: address(nftToken),
            tokenId: tokenId,
            seller: seller,
            payToken: address(defaultToken),
            price: price,
            isActive: true
        });

        bytes32 structHash = keccak256(abi.encode(
            v2Market.BUYNFT_TYPEHASH(),
            listing.nftContract,
            listing.tokenId,
            listing.seller,
            listing.payToken,
            listing.price,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            v2Market.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

        // 第一次购买成功
        vm.startPrank(buyer);
        defaultToken.approve(address(v2Market), price);
        v2Market.buyNFT(listing, buyer, deadline, v, r, s);
        vm.stopPrank();

        // 尝试使用相同的签名再次购买
        address anotherBuyer = makeAddr("anotherBuyer");
        defaultToken.mint(anotherBuyer, price);
        
        vm.startPrank(anotherBuyer);
        defaultToken.approve(address(v2Market), price);
        //vm.expectRevert("NFTMarket: Invalid signature");  // 或其他适当的错误消息
        vm.expectRevert("NFTMarket: Not the owner");  // 或其他适当的错误消息
        v2Market.buyNFT(listing, anotherBuyer, deadline, v, r, s);
        vm.stopPrank();
    }

    function testBatchListingWithSignatures() public {
        // 准备3个NFT和不同买家
        uint256[] memory tokenIds = new uint256[](3);
        address[] memory buyers = new address[](3);
        uint256 price = 100 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 days;

        for(uint i = 0; i < 3; i++) {
            tokenIds[i] = i + 1;
            buyers[i] = makeAddr(string.concat("buyer", vm.toString(i)));
            // 铸造NFT给卖家
            nftToken.mint(seller, tokenIds[i]);
            // 给买家铸造代币
            defaultToken.mint(buyers[i], price);
        }

        // 卖家一次性批量授权所有NFT给市场合约
        vm.startPrank(seller);
        nftToken.setApprovalForAll(address(v2Market), true);
        vm.stopPrank();

        // 为每个NFT生成独立的签名上架信息
        for(uint i = 0; i < 3; i++) {
            NFTMarketV2.Listing memory listing = NFTMarketV2.Listing({
                nftContract: address(nftToken),
                tokenId: tokenIds[i],
                seller: seller,
                payToken: address(defaultToken),
                price: price,
                isActive: true
            });

            bytes32 structHash = keccak256(abi.encode(
                v2Market.BUYNFT_TYPEHASH(),
                listing.nftContract,
                listing.tokenId,
                listing.seller,
                listing.payToken,
                listing.price,
                deadline
            ));

            bytes32 digest = keccak256(abi.encodePacked(
                "\x19\x01",
                v2Market.DOMAIN_SEPARATOR(),
                structHash
            ));

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);

            // 买家授权和购买
            vm.startPrank(buyers[i]);
            defaultToken.approve(address(v2Market), price);
            v2Market.buyNFT(listing, buyers[i], deadline, v, r, s);
            vm.stopPrank();

            // 验证每笔交易的结果
            assertEq(nftToken.ownerOf(tokenIds[i]), buyers[i]);
            assertEq(defaultToken.balanceOf(buyers[i]), 0);
        }

        // 验证卖家收到所有支付
        assertEq(defaultToken.balanceOf(seller), price * 3);
        
        // 验证批量授权状态保持不变
        assertTrue(nftToken.isApprovedForAll(seller, address(v2Market)));
    }
}
