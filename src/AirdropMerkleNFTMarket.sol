// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./IERC20Permit.sol";

contract NFTMarketV2 is IERC721Receiver, ReentrancyGuard {
    using Address for address;
    using SafeERC20 for IERC20;

    struct Listing {
        address nftContract;    // NFT合约地址
        uint256 tokenId;        // NFT的ID
        address seller;         // NFT卖家
        address payToken;       // 支付代币地址
        uint256 price;          // 价格
        bool isActive;          // 是否在售
    }


    // 默认支付代币合约地址
    IERC20 public defaultPaymentToken;
    
    // NFTContract -> tokenId -> Listing 双重映射
    mapping(address => mapping(uint256 => Listing)) public listings;

    // Mapping to track the deposit extended ERC20 balance for each address
    mapping(address => uint) public balances;
    bytes32 public immutable BUYNFT_TYPEHASH = keccak256("buyNFT(address nftContract,uint256 tokenId,address seller,address payToken,uint256 price,uint256 deadline)");
    bytes32 public immutable DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public immutable DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes('1')), block.chainid, address(this)));

    // 记录已使用的签名
    mapping(bytes32 => bool) public usedSignatures;
    string public constant name = "NFTMarket";

    // 事件声明
    event NFTListed(address indexed nftContract, address indexed seller, uint256 indexed tokenId, uint256 price);
    event ListingCanceled(address indexed nftContract, address indexed seller, uint256 indexed tokenId);
    event NFTSold(
        address indexed nftContract,
        address indexed seller,
        address indexed buyer,
        uint256 tokenId,
        address payToken,
        uint256 price
    );
    function initialize(address _defaultPaymentToken) external {
        require(isContract(_defaultPaymentToken), "NFTMarket: Payment token address must be a contract");
        defaultPaymentToken = IERC20(_defaultPaymentToken);
        
    }
    /**
    constructor(address _defaultPaymentToken) {
        require(isContract(_defaultPaymentToken), "NFTMarket: Payment token address must be a contract");
        defaultPaymentToken = IERC20(_defaultPaymentToken);
    }
    */

    function isContract(address addr) public view returns (bool) {
        uint256 size;
        // 直接调用汇编的 extcodesize 指令
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function getListingDetails(address nftContract, uint256 tokenId) public view returns (
        address seller, 
        uint256 price, 
        bool isActive,
        address payToken
    ) {
        Listing memory listing = listings[nftContract][tokenId];
        return (listing.seller, listing.price, listing.isActive, listing.payToken);
    }

    /**
     * @dev 上架NFT，可以指定支付代币
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param price 价格
     * @param payToken 指定支付代币地址，如果为address(0)则使用默认支付代币
     */
    function list(address nftContract, uint256 tokenId, uint256 price, address payToken) external {
        _list(nftContract, tokenId, price, payToken);
    }

    // 保持向后兼容的上架函数
    function list(address nftContract, uint256 tokenId, uint256 price) external {
        _list(nftContract, tokenId, price, address(0));
    }

    /**
     * @dev 上架NFT，可以指定支付代币
     * @param nftContract NFT合约地址
     * @param tokenId NFT的ID
     * @param price 价格
     * @param payToken 指定支付代币地址，如果为address(0)则使用默认支付代币
     */
    function _list(address nftContract, uint256 tokenId, uint256 price, address payToken) internal virtual {
        require(price > 0, "NFTMarket: Price must be greater than zero");
        require(isContract(nftContract), "NFTMarket: NFT address must be a contract");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: Not the owner");
        require(!listings[nftContract][tokenId].isActive, "NFTMarket: Already listed");
        // 如果payToken为0地址，使用默认支付代币
        address actualPayToken = payToken == address(0) ? address(defaultPaymentToken) : payToken;
        require(isContract(actualPayToken), "NFTMarket: Invalid payment token");

        // 创建listing
        listings[nftContract][tokenId] = Listing({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            isActive: true,
            payToken: actualPayToken
        });

        emit NFTListed(nftContract, msg.sender, tokenId, price);
    }

    /**
     * @dev Allows a designated buyer to purchase an NFT from the market.
     * @param listing The listing details of the NFT to be purchased.
     * @param buyer The address of the buyer who will purchase the NFT.
     * @param deadline The timestamp by which the purchase must be completed.
     * @param v The recovery id of the signature.
     * @param r The first 32 bytes of the signature.
     * @param s The second 32 bytes of the signature.
     */
    function buyNFT(
        Listing memory listing,
        address buyer,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        require(block.timestamp <= deadline, "Expired deadline");
        if (buyer == address(0)) {
            buyer = msg.sender;
        }
        require(buyer != listing.seller, "NFTMarket: Seller cannot be buyer");

        // 验证NFT所有权
        require(IERC721(listing.nftContract).ownerOf(listing.tokenId) == listing.seller, 
            "NFTMarket: Not the owner");
        
        bytes32 structHash = keccak256(abi.encode(
            BUYNFT_TYPEHASH,
            listing.nftContract,
            listing.tokenId,
            listing.seller,
            listing.payToken,
            listing.price,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));

        // 验证签名未被使用
        require(!usedSignatures[digest], "NFTMarket: Signature already used");
        
        // 验证签名者是NFT所有者
        address signer = ecrecover(digest, v, r, s);
        require(signer == listing.seller, "NFTMarket: Invalid signature");

        // 标记签名已使用
        usedSignatures[digest] = true;

        // 处理支付和NFT转移
        _toSwapNFT(listing, buyer);
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
        _toSwapNFT(listing, buyer);
    }

    function _toSwapNFT(Listing memory listing, address buyer) internal virtual {
        // 使用listing中指定的支付代币
        IERC20 payToken = IERC20(listing.payToken);
        uint originalBalance = payToken.balanceOf(listing.seller);
        payToken.safeTransferFrom(buyer, listing.seller, listing.price);
    
        require(payToken.balanceOf(listing.seller) >= originalBalance + listing.price, "NFTMarket: Payment transfer failed");

        // 转移NFT
        IERC721(listing.nftContract).safeTransferFrom(listing.seller, buyer, listing.tokenId);

        emit NFTSold(listing.nftContract, listing.seller, buyer, listing.tokenId, listing.payToken, listing.price);
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
        require(msg.sender == address(defaultPaymentToken), "Not my expected ERC20" );
        balances[tx.origin] += amount;
        
        if (data.length == 64) {
            // decode nftContract and tokenId
            (address nftContract, uint256 tokenId) = abi.decode(data, (address, uint256));
            Listing memory listing = listings[nftContract][tokenId];
            require(listing.isActive, "NFTMarket: Not listed");
            require(tx.origin != listing.seller, "NFTMarket: Seller cannot be buyer");

            listings[nftContract][tokenId].isActive = false;

            defaultPaymentToken.safeTransfer(listing.seller, listing.price);

            uint leftToken = amount - listing.price;
            if (leftToken > 0) defaultPaymentToken.safeTransfer(tx.origin, leftToken);

            IERC721(nftContract).safeTransferFrom(listing.seller, tx.origin, tokenId);

            emit NFTSold(listing.nftContract, listing.seller, tx.origin, listing.tokenId, listing.payToken, listing.price);
        }
        return true;
    }    
}
contract AirdropMerkleNFTMarket is NFTMarketV2 {
    using SafeERC20 for IERC20;
    bytes32 public immutable merkleRoot;
    mapping(address => bool) public claimed;
    
    constructor(address _defaultPaymentToken, bytes32 _merkleRoot) {
        defaultPaymentToken = IERC20(_defaultPaymentToken);
        merkleRoot = _merkleRoot;
    }

    struct Call {
        address target;
        bytes callData;
    }

    function multicall(Call[] calldata calls) external returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = calls[i].target.delegatecall(calls[i].callData);
            require(success, "Call failed");
            results[i] = result;
        }
    }

    function permitPrePay(
        address token,
        PermitStruct calldata permitData,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(token).permit(permitData, v, r, s);
    }

    function claimNFT(
        address nftContract,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external {
        require(!claimed[msg.sender], "Already claimed");
        
        // 验证merkle证明
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, leaf),
            "Invalid merkle proof"
        );

        Listing memory listing = listings[nftContract][tokenId];
        require(listing.isActive, "NFT not listed");
        
        // 白名单用户50%折扣
        uint256 discountedPrice = listing.price / 2;
        
        // 转移代币和NFT
        IERC20(listing.payToken).safeTransferFrom(
            msg.sender,
            listing.seller,
            discountedPrice
        );
        
        listings[nftContract][tokenId].isActive = false;
        claimed[msg.sender] = true;

        IERC721(nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );
        emit NFTSold(
            nftContract,
            listing.seller,
            msg.sender,
            tokenId,
            listing.payToken,
            discountedPrice
        );
    }
}


//