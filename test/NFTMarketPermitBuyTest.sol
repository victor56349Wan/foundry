pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NFTMarketPermitBuy.sol";
import "../src/ExtERC20.sol";
import "../src/BaseERC721.sol";

contract NFTMarketPermitBuyTest is Test {
    NFTMarketPermitBuy public nftMarket;
    ExtERC20 public erc20Token;
    BaseERC721 public nftToken;
    uint256 public tokenId = 0;
    uint256 ownerPrivateKey;
    address owner;

    function setUp() public {
        string memory baseURI = "ipfs://QmdYeDpkVZedk1mkGodjNmF35UNxwafhFLVvsHrWgJoz6A/beanz_metadata";
        erc20Token = new ExtERC20("MockERC20", "MERC20", 18, 10**6);
        nftToken = new BaseERC721("MockERC721", "MNFT", baseURI);
        nftMarket = new NFTMarketPermitBuy(address(erc20Token));

        // 创建NFT持有者账户
        (owner, ownerPrivateKey) = makeAddrAndKey("owner");
        
        // 铸造NFT给owner
        nftToken.mint(owner, tokenId);
    }

    function testPermitBuySuccess() public {
        // 设置NFT上架
        uint256 price = 100 * 10**18;
        address buyer = makeAddr("buyer");
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(owner);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        // 准备签名数据
        bytes32 permitBuyStructHash = keccak256(
            abi.encode(
                nftMarket.PERMITBUY_TYPEHASH(),
                address(nftToken),
                buyer,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                nftMarket.DOMAIN_SEPARATOR(),
                permitBuyStructHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // 给买家铸造代币
        erc20Token.mint(buyer, price);
        
        // 买家进行购买
        vm.startPrank(buyer);
        erc20Token.approve(address(nftMarket), price);
        nftMarket.permitBuy(
            address(nftToken),
            buyer,
            deadline,
            tokenId,
            v, r, s
        );
        vm.stopPrank();

        // 验证购买结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(erc20Token.balanceOf(owner), price);
    }

    function testPermitBuyExpiredDeadline() public {
        uint256 price = 100 * 10**18;
        address buyer = makeAddr("buyer");
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(owner);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        bytes32 permitBuyStructHash = keccak256(
            abi.encode(
                nftMarket.PERMITBUY_TYPEHASH(),
                address(nftToken),
                buyer,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                nftMarket.DOMAIN_SEPARATOR(),
                permitBuyStructHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        // 时间前进超过deadline
        vm.warp(deadline + 1);

        vm.expectRevert("expired deadline");
        nftMarket.permitBuy(
            address(nftToken),
            buyer,
            deadline,
            tokenId,
            v, r, s
        );
    }

    function testPermitBuyInvalidSigner() public {
        uint256 price = 100 * 10**18;
        address buyer = makeAddr("buyer");
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(owner);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        // 使用错误的私钥签名
        (,uint256 wrongPrivateKey) = makeAddrAndKey("wrong");
        
        bytes32 permitBuyStructHash = keccak256(
            abi.encode(
                nftMarket.PERMITBUY_TYPEHASH(),
                address(nftToken),
                buyer,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                nftMarket.DOMAIN_SEPARATOR(),
                permitBuyStructHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);

        vm.expectRevert("invalid signer");
        nftMarket.permitBuy(
            address(nftToken),
            buyer,
            deadline,
            tokenId,
            v, r, s
        );
    }

    function testPermitBuyByThirdParty() public {
        uint256 price = 100 * 10**18;
        address buyer = makeAddr("buyer");
        address thirdParty = makeAddr("thirdParty");
        uint256 deadline = block.timestamp + 1 days;

        vm.startPrank(owner);
        nftToken.approve(address(nftMarket), tokenId);
        nftMarket.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        bytes32 permitBuyStructHash = keccak256(
            abi.encode(
                nftMarket.PERMITBUY_TYPEHASH(),
                address(nftToken),
                buyer,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                nftMarket.DOMAIN_SEPARATOR(),
                permitBuyStructHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        erc20Token.mint(buyer, price);
        
        vm.startPrank(buyer);
        erc20Token.approve(address(nftMarket), price);
        vm.stopPrank();
        vm.startPrank(thirdParty);
        nftMarket.permitBuy(
            address(nftToken),
            buyer,
            deadline,
            tokenId,
            v, r, s
        );
        vm.stopPrank();

        // 验证购买结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(erc20Token.balanceOf(owner), price);
        assertEq(erc20Token.balanceOf(thirdParty), 0);
    }
}
