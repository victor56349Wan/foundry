pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AirdropMerkleNFTMarket.sol";
import "../src/erc20Permit.sol";
import "../src/BaseERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropMerkleNFTMarketTest is Test {
    AirdropMerkleNFTMarket public market;
    ERC20Permit public token;
    BaseERC721 public nftToken;
    address[] public whitelistAddresses;
    bytes32[] public whitelistLeaves;
    bytes32 public merkleRoot;
    
    uint256 sellerPrivateKey;
    address seller;  
    uint256 buyerPrivateKey;  // 添加buyer的私钥

    function setUp() public {
        // 创建白名单 - 修改为4个地址
        whitelistAddresses = new address[](4);
        whitelistAddresses[0] = makeAddr("user1");
        whitelistAddresses[1] = makeAddr("user2");
        whitelistAddresses[2] = makeAddr("user3");
        whitelistAddresses[3] = makeAddr("user4");

        (seller, sellerPrivateKey) = makeAddrAndKey("seller");
        
        // 为白名单用户buyer0生成私钥
        address buyer0 = whitelistAddresses[0];
        buyerPrivateKey = uint256(keccak256(abi.encodePacked("buyer0")));
        // 更新白名单地址为有对应私钥的地址
        whitelistAddresses[0] = vm.addr(buyerPrivateKey);

        // 构建merkle树
        whitelistLeaves = new bytes32[](whitelistAddresses.length);
        for(uint i = 0; i < whitelistAddresses.length; i++) {
            whitelistLeaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }
        merkleRoot = calculateMerkleRoot(whitelistLeaves);

        // 部署合约
        token = new ERC20Permit("Test Token", "TEST", 18, 1000000 ether);
        nftToken = new BaseERC721("Test NFT", "NFT", "");
        market = new AirdropMerkleNFTMarket(address(token), merkleRoot);
    }

    function testWhitelistClaimWithMulticall() public {
        //address seller = makeAddr("seller");

        address buyer = whitelistAddresses[0]; // 使用有私钥的buyer地址
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 days;

        // 准备NFT和代币
        nftToken.mint(seller, tokenId);
        token.transfer(buyer, price);

        vm.startPrank(seller);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        bytes32[] memory proof = getProof(buyer);

        // 准备multicall数据
        AirdropMerkleNFTMarket.Call[] memory calls = new AirdropMerkleNFTMarket.Call[](2);

        // permitPrePay调用数据
        PermitStruct memory permitData = PermitStruct({
            owner: address(buyer),
            spender: address(market),
            value: price / 2,
            nonce: token.nonces(buyer),
            deadline: deadline
        });
        console.log("msg.sender", msg.sender);
        console.log("tx.origin", tx.origin);
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            buyer,
            address(market),
            price / 2,
            deadline,
            buyerPrivateKey  // 使用buyer的私钥
        );
        //token.permit(permitData, v, r, s);
        calls[0].target = address(market);
        calls[0].callData = abi.encodeWithSelector(
            market.permitPrePay.selector, 
            token,
            permitData,
            v, r, s
        );

        // claimNFT调用数据
        calls[1].target = address(market);
        calls[1].callData = abi.encodeWithSelector(
            market.claimNFT.selector,
            address(nftToken),
            tokenId,
            proof
        );

        vm.startPrank(buyer);
        market.multicall(calls);
        vm.stopPrank();

        // 验证结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price / 2);
        assertTrue(market.claimed(buyer));
    }

    // 添加新的测试函数
    function testWhitelistClaimWithEvenLeaves() public {
        address buyer = whitelistAddresses[0];
        uint256 tokenId = 1;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 days;

        // 准备NFT和代币
        nftToken.mint(seller, tokenId);
        token.transfer(buyer, price);

        vm.startPrank(seller);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);
        vm.stopPrank();

        bytes32[] memory proof = getProof(buyer);
        
        // 验证Merkle证明的正确性
        bool isValid = MerkleProof.verify(
            proof,
            merkleRoot,
            keccak256(abi.encodePacked(buyer))
        );
        assertTrue(isValid, "Merkle proof should be valid");

        // 准备multicall数据
        AirdropMerkleNFTMarket.Call[] memory calls = new AirdropMerkleNFTMarket.Call[](2);

        PermitStruct memory permitData = PermitStruct({
            owner: address(buyer),
            spender: address(market),
            value: price / 2,
            nonce: token.nonces(buyer),
            deadline: deadline
        });

        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            buyer,
            address(market),
            price / 2,
            deadline,
            buyerPrivateKey
        );

        calls[0].target = address(market);
        calls[0].callData = abi.encodeWithSelector(
            market.permitPrePay.selector,
            token,
            permitData,
            v, r, s
        );

        calls[1].target = address(market);
        calls[1].callData = abi.encodeWithSelector(
            market.claimNFT.selector,
            address(nftToken),
            tokenId,
            proof
        );

        vm.startPrank(buyer);
        market.multicall(calls);
        vm.stopPrank();

        // 验证结果
        assertEq(nftToken.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price / 2);
        assertTrue(market.claimed(buyer));
    }

    function calculateMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        
        bytes32[] memory currentLevel = leaves;
        
        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);
            
            for (uint i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    // 排序后再哈希,确保一致性
                    bytes32 left = currentLevel[i];
                    bytes32 right = currentLevel[i + 1];
                    nextLevel[i/2] = keccak256(abi.encodePacked(
                        left < right ? left : right,
                        left < right ? right : left
                    ));
                } else {
                    nextLevel[i/2] = currentLevel[i];
                }
            }
            currentLevel = nextLevel;
        }
        
        return currentLevel[0];
    }

    function getProof(address account) internal view returns (bytes32[] memory) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        uint256 index = type(uint256).max;
        
        // 找到账户对应的叶子节点位置
        for(uint i = 0; i < whitelistLeaves.length; i++) {
            if(whitelistLeaves[i] == leaf) {
                index = i;
                break;
            }
        }
        require(index != type(uint256).max, "Account not in whitelist");

        uint256 numLeaves = whitelistLeaves.length;
        uint256 numLevels = 0;
        uint256 n = numLeaves;
        while (n > 1) {
            numLevels++;
            n = (n + 1) / 2;
        }

        bytes32[] memory proof = new bytes32[](numLevels);
        bytes32[] memory nodes = new bytes32[](numLeaves);
        for (uint i = 0; i < numLeaves; i++) {
            nodes[i] = whitelistLeaves[i];
        }

        uint256 levelSize = numLeaves;
        uint256 proofIndex = 0;
        uint256 currentIndex = index;

        while (levelSize > 1) {
            uint256 numPairs = levelSize / 2;
            uint256 oddNode = levelSize % 2 == 1 ? levelSize - 1 : type(uint256).max;

            if (currentIndex < levelSize) {
                uint256 pairIndex = currentIndex % 2 == 0 ? currentIndex + 1 : currentIndex - 1;
                
                if (pairIndex < levelSize) {
                    proof[proofIndex++] = nodes[pairIndex];
                }
            }

            bytes32[] memory newNodes = new bytes32[]((levelSize + 1) / 2);
            for (uint i = 0; i < numPairs; i++) {
                bytes32 left = nodes[i * 2];
                bytes32 right = nodes[i * 2 + 1];
                newNodes[i] = keccak256(abi.encodePacked(
                    left < right ? left : right,
                    left < right ? right : left
                ));
            }

            if (oddNode != type(uint256).max) {
                newNodes[numPairs] = nodes[oddNode];
            }

            nodes = newNodes;
            levelSize = (levelSize + 1) / 2;
            currentIndex = currentIndex / 2;
        }

        // 验证生成的证明
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            if (proof[i] == bytes32(0)) continue;
            computedHash = computedHash < proof[i] 
                ? keccak256(abi.encodePacked(computedHash, proof[i]))
                : keccak256(abi.encodePacked(proof[i], computedHash));
        }
        
        require(computedHash == merkleRoot, "Invalid proof generated");
        
        return proof;
    }

    function getMaxDepth() internal view returns (uint256) {
        uint256 n = whitelistLeaves.length;
        uint256 depth = 0;
        while(n > 0) {
            depth++;
            n = n / 2;
        }
        return depth;
    }

    function getPermitSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint256 privateKey  // 添加私钥参数
    ) internal view returns (uint8, bytes32, bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                token.PERMIT_TYPEHASH(),
                owner,
                spender,
                value,
                token.nonces(owner),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        return vm.sign(privateKey, digest);  // 使用传入的privateKey
    }
}
