// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract NFTMarket is IERC721Receiver, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;
    // 市场中的NFT列表结构
    struct Listing {
        address nftContract;  // NFT合约地址
        address seller;      // NFT卖家
        uint256 price;       // 价格（以ERC20代币计价）
        bool isActive;       // 是否在售
    }

    // 支付代币合约地址
    IERC20 public immutable paymentToken;
    
    // NFTContract -> tokenId -> Listing 双重映射
    mapping(address => mapping(uint256 => Listing)) public listings;

    // Mapping to track the deposit extended ERC20 balance for each address
    mapping(address => uint) public balances;

    // 事件声明
    event NFTListed(address indexed nftContract, address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed nftContract, address indexed seller, address indexed buyer, uint256 tokenId, uint256 price);
    event ListingCanceled(address indexed nftContract, address indexed seller, uint256 indexed tokenId);

    constructor(address _paymentToken) {
        require(isContract(_paymentToken), "NFTMarket: Payment token address must be a contract");
        paymentToken = IERC20(_paymentToken);
    }

    function isContract(address addr) public view returns (bool) {
        uint256 size;
        // 直接调用汇编的 extcodesize 指令
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function getListingDetails(address nftContract, uint256 tokenId) public view returns (address seller, uint256 price, bool isActive) {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }    

    /**
     * @dev 上架NFT
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param price 价格（以ERC20代币计价）
     */
    function list(address nftContract, uint256 tokenId, uint256 price) external {
        require(price > 0, "NFTMarket: Price must be greater than zero");
        require(isContract(nftContract), "NFTMarket: NFT address must be a contract");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: Not the owner");
        require(!listings[nftContract][tokenId].isActive, "NFTMarket: Already listed");

        // 创建listing
        listings[nftContract][tokenId] = Listing({
            nftContract: nftContract,
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(nftContract, msg.sender, tokenId, price);
    }

    /**
     * @dev 购买NFT
     * @param nftContract NFT合约地址
     * @param tokenId 要购买的NFT的ID
     * @param buyer 指定的买家地址
     */
    function buyNFT(address nftContract, uint256 tokenId, address buyer) external nonReentrant {
        if (buyer == address(0)) {
            buyer = msg.sender;
        }
        
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFTMarket: Not listed");
        require(buyer != listing.seller, "NFTMarket: Seller cannot be buyer");

        // 更新listing状态
        listings[nftContract][tokenId].isActive = false;

        // 转移支付代币, 然后检查余额变化
        uint originalBalance = paymentToken.balanceOf(listing.seller);
        paymentToken.safeTransferFrom(buyer, listing.seller, listing.price);
    
        require(paymentToken.balanceOf(listing.seller) >= originalBalance + listing.price, "NFTMarket: Payment transfer failed");

        // 转移NFT
        IERC721(nftContract).safeTransferFrom(listing.seller, buyer, tokenId);

        emit NFTSold(nftContract, listing.seller, buyer, tokenId, listing.price);
    }

    /**
     * @dev 取消上架
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     */
    function cancelListing(address nftContract, uint256 tokenId) external {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFTMarket: Not listed");
        require(msg.sender == listing.seller, "NFTMarket: Not the seller");

        // 更新listing状态
        listings[nftContract][tokenId].isActive = false;

        emit ListingCanceled(nftContract, msg.sender, tokenId);
    }

    /**
     * @dev 查看NFT当前价格
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     */
    function getPrice(address nftContract, uint256 tokenId) external view returns (uint256) {
        require(listings[nftContract][tokenId].isActive, "NFTMarket: Not listed");
        return listings[nftContract][tokenId].price;
    }

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

    // callback for transferWithCallback() in my extended ERC20 contract
    function tokensReceived(uint amount,  bytes memory data) external returns(bool){
        require(msg.sender == address(paymentToken), "Not my expected ERC20" );
        balances[tx.origin] += amount;
        
        if (data.length == 64) {
            // decode nftContract and tokenId
            (address nftContract, uint256 tokenId) = abi.decode(data, (address, uint256));
            Listing memory listing = listings[nftContract][tokenId];
            require(listing.isActive, "NFTMarket: Not listed");
            require(tx.origin != listing.seller, "NFTMarket: Seller cannot be buyer");

            listings[nftContract][tokenId].isActive = false;

            paymentToken.safeTransfer(listing.seller, listing.price);

            uint leftToken = amount - listing.price;
            if (leftToken > 0) paymentToken.safeTransfer(tx.origin, leftToken);

            IERC721(nftContract).safeTransferFrom(listing.seller, tx.origin, tokenId);

            emit NFTSold(nftContract, listing.seller, tx.origin, tokenId, listing.price);
        }
        return true;
    }    
}
