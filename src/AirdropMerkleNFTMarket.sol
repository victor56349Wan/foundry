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
import "./NFTMarketV2.sol";

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