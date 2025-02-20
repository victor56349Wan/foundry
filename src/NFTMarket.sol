// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NFTMarket is IERC721Receiver, ReentrancyGuard {
    using Address for address;

    // 市场中的NFT列表结构
    struct Listing {
        address seller;      // NFT卖家
        uint256 price;       // 价格（以ERC20代币计价）
        bool isActive;       // 是否在售
    }

    // NFT合约地址
    IERC721 public immutable nftContract;
    // 支付代币合约地址
    IERC20 public immutable paymentToken;
    
    // NFT -> Listing 映射
    mapping(uint256 => Listing) public listings;

    // Mapping to track the deposit extended ERC20 balance for each address
    mapping(address => uint) public balances;

    // 事件声明
    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event ListingCanceled(address indexed seller, uint256 indexed tokenId);
    function isContract(address addr) public view returns (bool) {
        uint256 size;
        // 直接调用汇编的 extcodesize 指令
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
    function getListingDetails(uint256 tokenId) public view returns (address, uint256, bool) {
        Listing memory listing = listings[tokenId];
        return (listing.seller, listing.price, listing.isActive);
    }    
    constructor(address _nftContract, address _paymentToken) {
        require(isContract(_nftContract), "NFTMarket: NFT address must be a contract");
        require(isContract(_paymentToken), "NFTMarket: Payment token address must be a contract");
        nftContract = IERC721(_nftContract);
        paymentToken = IERC20(_paymentToken);
    }

    /**
     * @dev 上架NFT
     * @param tokenId NFT的ID
     * @param price 价格（以ERC20代币计价）
     */
    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "NFTMarket: Price must be greater than zero");
        require(nftContract.ownerOf(tokenId) == msg.sender, "NFTMarket: Not the owner");
        require(!listings[tokenId].isActive, "NFTMarket: Already listed");

        // nft保留在seller处
        // nftContract.safeTransferFrom(msg.sender, msg.sender, tokenId);

        // 创建listing
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });

        emit NFTListed(msg.sender, tokenId, price);
    }

    /**
     * @dev 购买NFT
     * @param tokenId 要购买的NFT的ID
     */
    function buyNFT(uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "NFTMarket: Not listed");
        require(msg.sender != listing.seller, "NFTMarket: Seller cannot be buyer");

        // 更新listing状态
        listings[tokenId].isActive = false;

        // 转移支付代币
        require(
            paymentToken.transferFrom(msg.sender, listing.seller, listing.price),
            "NFTMarket: Payment transfer failed"
        );

        // 转移NFT
        nftContract.safeTransferFrom(listing.seller, msg.sender, tokenId);

        emit NFTSold(listing.seller, msg.sender, tokenId, listing.price);
    }

    /**
     * @dev 取消上架
     * @param tokenId NFT的ID
     */
    function cancelListing(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "NFTMarket: Not listed");
        require(msg.sender == listing.seller, "NFTMarket: Not the seller");

        // 更新listing状态
        listings[tokenId].isActive = false;

        // 将NFT返还给卖家
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);

        emit ListingCanceled(msg.sender, tokenId);
    }

    /**
     * @dev 查看NFT当前价格
     * @param tokenId NFT的ID
     */
    function getPrice(uint256 tokenId) external view returns (uint256) {
        require(listings[tokenId].isActive, "NFTMarket: Not listed");
        return listings[tokenId].price;
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
        uint tokenId;
        if (data.length == 32) {
            // tokenId for desired NFT
            tokenId = abi.decode(data, (uint));
            Listing memory listing = listings[tokenId];
                require(listing.isActive, "NFTMarket: Not listed");
                require(msg.sender != listing.seller, "NFTMarket: Seller cannot be buyer");

                // 更新listing状态
                listings[tokenId].isActive = false;

                // 转移支付代币给seller
                require(
                    paymentToken.transfer(listing.seller, listing.price),
                    "NFTMarket: Payment transfer failed"
                );

                //转移NFT
                nftContract.safeTransferFrom(address(this), tx.origin, tokenId);

                emit NFTSold(listing.seller, tx.origin, tokenId, listing.price);
        }
        return true;
    }    
}
