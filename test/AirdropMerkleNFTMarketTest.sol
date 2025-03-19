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
        
        // 生成buyer0的私钥并设置地址
        buyerPrivateKey = uint256(keccak256(abi.encodePacked("buyer0")));
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
        //console.log("msg.sender", msg.sender);
        //console.log("tx.origin", tx.origin);
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

    function buildMerkleTree() internal view returns (bytes32) {
        uint256 n = whitelistLeaves.length;
        require(n > 0, "Empty whitelist");
        
        // 复制叶子节点数组，避免修改原数组
        bytes32[] memory nodes = new bytes32[](n);
        for(uint256 i = 0; i < n; i++) {
            nodes[i] = whitelistLeaves[i];
        }
        
        // 从底向上构建树
        while(n > 1) {
            for(uint256 i = 0; i < n/2; i++) {
                bytes32 left = nodes[i*2];
                bytes32 right = i*2+1 < n ? nodes[i*2+1] : left;
                nodes[i] = keccak256(abi.encodePacked(
                    left <= right ? left : right,
                    left <= right ? right : left
                ));
            }
            n = (n + 1) / 2;
        }
        
        return nodes[0];
    }

    function getMerkleProof(uint256 index) internal view returns (bytes32[] memory) {
        uint256 n = whitelistLeaves.length;
        require(index < n, "Index out of bounds");

        // 计算证明长度
        uint256 proofLength = 0;
        uint256 temp = n;
        while(temp > 1) {
            proofLength++;
            temp = (temp + 1) / 2;
        }

        bytes32[] memory proof = new bytes32[](proofLength);
        uint256 proofIndex = 0;
        uint256 levelSize = n;
        uint256 currentIndex = index;

        // 复制叶子节点层
        bytes32[] memory nodes = new bytes32[](n);
        for(uint256 i = 0; i < n; i++) {
            nodes[i] = whitelistLeaves[i];
        }

        // 从底向上构建证明
        while(levelSize > 1) {
            if(currentIndex % 2 == 0) {
                if(currentIndex + 1 < levelSize) {
                    proof[proofIndex++] = nodes[currentIndex + 1];
                }
            } else {
                proof[proofIndex++] = nodes[currentIndex - 1];
            }

            // 计算下一层
            uint256 nextLevelSize = (levelSize + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelSize);
            for(uint256 i = 0; i < levelSize; i += 2) {
                bytes32 left = nodes[i];
                bytes32 right = i + 1 < levelSize ? nodes[i + 1] : left;
                nextLevel[i/2] = keccak256(abi.encodePacked(
                    left <= right ? left : right,
                    left <= right ? right : left
                ));
            }

            nodes = nextLevel;
            levelSize = nextLevelSize;
            currentIndex /= 2;
        }

        return proof;
    }

    function processPurchase(
        address buyer,
        uint256 privateKey,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes32[] memory proof
    ) internal {
        // 准备multicall数据
        AirdropMerkleNFTMarket.Call[] memory calls = new AirdropMerkleNFTMarket.Call[](2);
        
        // permitPrePay调用数据
        calls[0].target = address(market);
        calls[0].callData = preparePermitCallData(
            buyer,
            privateKey,
            price / 2,
            deadline
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
    }


    // 添加模糊测试函数
  
    function testFuzzWhitelistClaim(uint256 numAddresses) public {
        // --- snip ---
        // 无需制白名单大小为2的幂次方，避免merkle树构建问题
        console.log("Whitelist length for Fuzz testing:", numAddresses);
        vm.assume(numAddresses > 0 && numAddresses <= 128);
        // 初始化代币
        token = new ERC20Permit("Test Token", "TEST", 18, 1000000 ether);
        nftToken = new BaseERC721("Test NFT", "NFT", "");
        
        // 初始化白名单并部署市场合约
        (uint256[] memory privateKeys, address[] memory buyers) = setupWhitelist(numAddresses);

        // 单个处理每个白名单地址
        for(uint256 i = 0; i < numAddresses; i++) {
            //console.log("Processing address:", i, buyers[i]);
            processWhitelistClaim(i, privateKeys[i], buyers[i]);
        }
    }

    function processWhitelistClaim(
        uint256 index,
        uint256 privateKey,
        address buyer
    ) internal {
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256 tokenId = index + 1;
        
        // 准备NFT和代币
        setupNFTAndTokens(buyer, tokenId, price);
        
        // 获取merkle证明
        bytes32[] memory proof = getProof(buyer);
        /**
        bytes32 leaf = keccak256(abi.encodePacked(buyer));
        console.log('--------');
        console.log('leaf', vm.toString(leaf));
        console.log('merkleRoot', vm.toString(merkleRoot));
        for (uint i = 0; i < proof.length; i++ ){
            console.logBytes32(proof[i]);
        }        
         */
        bool isValid = verifyProof(buyer, proof);
        assertTrue(isValid, string(abi.encodePacked("Invalid proof for address ", vm.toString(index), vm.toString(buyer))));
        
        // 准备multicall数据
        AirdropMerkleNFTMarket.Call[] memory calls = new AirdropMerkleNFTMarket.Call[](2);
        calls[0].target = address(market);
        calls[0].callData = preparePermitCallData(
            buyer,
            privateKey,
            price / 2,
            deadline
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
        
        verifyPurchase(buyer, tokenId, price / 2, index);
    }
  function setupWhitelistForDebugMerkleTree(uint256 numAddresses) internal returns (uint256[] memory, address[] memory) {
        delete whitelistAddresses;
        delete whitelistLeaves;
        whitelistAddresses = new address[](numAddresses);
        whitelistLeaves = new bytes32[](numAddresses);
        uint256[] memory privateKeys = new uint256[](numAddresses);

        uint256[3] memory _privateKeys = [
            40532752661558610254906589951903782552509948745928801020266477369763214292834,
            78335435947560623321582890333859224782807270913315105621689772912996559270004,
            35731867869253855677061141599122844102079267647692521477175961271446553405018                  
        ];
        address[3] memory _buyers = [
            0x7DD6eFEA1e6cE7cB070B279febDa8E180dE0dba9,
            0x7EF5654f7BBc8eA410Bd768b54a11d1297238632,
            0x24e290522DE8517F2a47616Ae02887f45d6B9Acf            
        ];
        for(uint i = 0; i < numAddresses; i++) {
            privateKeys[i] = _privateKeys[i];
            whitelistAddresses[i] = _buyers[i];
            whitelistLeaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
            /**
            console.log("leaf No:", i);
            console.log("address:", whitelistAddresses[i]);
            console.logBytes32(whitelistLeaves[i]);
             */

        }    
   
        merkleRoot = calculateMerkleRoot(whitelistLeaves);
        market = new AirdropMerkleNFTMarket(address(token), merkleRoot);
        
        return (privateKeys, whitelistAddresses);
    }
    function setupWhitelist(uint256 numAddresses) internal returns (uint256[] memory, address[] memory) {
        delete whitelistAddresses;
        delete whitelistLeaves;
        whitelistAddresses = new address[](numAddresses);
        whitelistLeaves = new bytes32[](numAddresses);
        uint256[] memory privateKeys = new uint256[](numAddresses);
        
        for(uint i = 0; i < numAddresses; i++) {
            // 使用确定性的私钥生成
            string memory userKey = string(abi.encodePacked("user", vm.toString(i), "key"));
            privateKeys[i] = uint256(keccak256(abi.encodePacked(userKey)));
            whitelistAddresses[i] = vm.addr(privateKeys[i]);
            whitelistLeaves[i] = keccak256(abi.encodePacked(whitelistAddresses[i]));
        }
        
        merkleRoot = calculateMerkleRoot(whitelistLeaves);
        market = new AirdropMerkleNFTMarket(address(token), merkleRoot);
        
        return (privateKeys, whitelistAddresses);
    }

    // 新增批处理函数
    function processWhitelistBatch(
        uint256 startIndex,
        uint256 endIndex,
        uint256[] memory privateKeys,
        address[] memory buyers
    ) internal {
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 days;
        
        for(uint256 i = startIndex; i < endIndex; i++) {
            address buyer = buyers[i];
            uint256 tokenId = i + 1;
            
            setupNFTAndTokens(buyer, tokenId, price);
            
            AirdropMerkleNFTMarket.Call[] memory calls = new AirdropMerkleNFTMarket.Call[](2);
            calls[0].target = address(market);
            calls[0].callData = preparePermitCallData(
                buyer,
                privateKeys[i],
                price / 2,
                deadline
            );
            
            bytes32[] memory proof = getProof(buyer);
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
            
            verifyPurchase(buyer, tokenId, price / 2, i);
        }
    }
    
    function setupNFTAndTokens(address buyer, uint256 tokenId, uint256 amount) internal {
        nftToken.mint(seller, tokenId);
        token.transfer(buyer, amount);
        
        vm.startPrank(seller);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, amount);
        vm.stopPrank();
    }
    
    function verifyPurchase(
        address buyer,
        uint256 tokenId,
        uint256 price,
        uint256 index
    ) internal view {
        assertEq(nftToken.ownerOf(tokenId), buyer, 
            string(abi.encodePacked("NFT transfer failed for address ", vm.toString(index))));
        assertEq(token.balanceOf(seller), (index + 1) * price,
            string(abi.encodePacked("Incorrect seller balance after sale ", vm.toString(index))));
        assertTrue(market.claimed(buyer),
            string(abi.encodePacked("Claim status not set for address ", vm.toString(index))));
    }

    // 新增辅助函数
    function preparePermitCallData(
        address buyer,
        uint256 buyerKey,
        uint256 value,
        uint256 deadline
    ) internal view returns (bytes memory) {
        PermitStruct memory permitData = PermitStruct({
            owner: buyer,
            spender: address(market),
            value: value,
            nonce: token.nonces(buyer),
            deadline: deadline
        });
        
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            buyer,
            address(market),
            value,
            deadline,
            buyerKey
        );
        
        return abi.encodeWithSelector(
            market.permitPrePay.selector,
            token,
            permitData,
            v, r, s
        );
    }
    
    function testNonWhitelistPurchase() public {
        address nonWhitelistBuyer = makeAddr("nonWhitelist");
        uint256 privateKey = uint256(keccak256(abi.encodePacked("nonWhitelist", "key")));
        nonWhitelistBuyer = vm.addr(privateKey);
        
        uint256 tokenId = 999;
        uint256 price = 100 ether;
        uint256 deadline = block.timestamp + 1 days;
        
        // 准备NFT和代币
        nftToken.mint(seller, tokenId);
        token.transfer(nonWhitelistBuyer, price);
        
        vm.startPrank(seller);
        nftToken.approve(address(market), tokenId);
        market.list(address(nftToken), tokenId, price);
        vm.stopPrank();
        
        vm.startPrank(nonWhitelistBuyer);
        
        // 准备multicall数据
        AirdropMerkleNFTMarket.Call[] memory calls = new AirdropMerkleNFTMarket.Call[](2);
        
        // permitPrePay调用数据
        PermitStruct memory permitData = PermitStruct({
            owner: nonWhitelistBuyer,
            spender: address(market),
            value: price,  // 注意这里是全价
            nonce: token.nonces(nonWhitelistBuyer),
            deadline: deadline
        });
        
        (uint8 v, bytes32 r, bytes32 s) = getPermitSignature(
            nonWhitelistBuyer,
            address(market),
            price,
            deadline,
            privateKey
        );
        
        calls[0].target = address(market);
        calls[0].callData = abi.encodeWithSelector(
            market.permitPrePay.selector,
            token,
            permitData,
            v, r, s
        );
        
        // buy调用数据
        calls[1].target = address(market);
        calls[1].callData = abi.encodeCall(
            market.buyNFT1,
            (
                address(nftToken), // nftContract
                tokenId,          // tokenId
                nonWhitelistBuyer // buyer
            )
        );
        
        market.multicall(calls);
        vm.stopPrank();
        
        // 验证结果
        assertEq(nftToken.ownerOf(tokenId), nonWhitelistBuyer);
        assertEq(token.balanceOf(seller), price); // 全价支付
        assertFalse(market.claimed(nonWhitelistBuyer)); // 不应该被标记为已领取
    }

    // 添加辅助函数用于验证merkle证明
    function verifyProof(address account, bytes32[] memory proof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function calculateMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "Empty leaves");
        
        uint256 n = leaves.length;
        bytes32[] memory level = leaves;
        
        // 确保每层都按顺序处理叶子节点
        while (n > 1) {
            uint256 offset = 0;
            uint256 nextLevelSize = (n + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelSize);
            
            //console.log("current level size", nextLevelSize);
            for (uint256 i = 0; i < n - 1; i += 2) {
                //console.logBytes32(level[i]);
                //console.logBytes32(level[i + 1]);
                nextLevel[offset++] = hashPair(level[i], level[i + 1]);
                //console.log("offset : ", offset);
                //console.logBytes32(nextLevel[offset - 1]);
            }
            
            // 处理最后一个单独的节点
            if (n % 2 == 1) {
                nextLevel[offset] = level[n - 1];
            }
            
            level = nextLevel;
            n = nextLevelSize;
            //.log("current level size", n);
            
        }
        
        return level[0];
    }

    function getProof(address account) internal view returns (bytes32[] memory) {
        bytes32 leaf = keccak256(abi.encodePacked(account));
        uint256 index = type(uint256).max;
        
        // 查找叶子节点的位置
        for(uint256 i = 0; i < whitelistLeaves.length; i++) {
            if(whitelistLeaves[i] == leaf) {
                index = i;
                break;
            }
        }
        require(index != type(uint256).max, "Account not in whitelist");

        // 计算所需的证明深度
        uint256 numLeaves = whitelistLeaves.length;
        uint256 depth = 0;
        while((1 << depth) < numLeaves) {
            depth++;
        }
        
        bytes32[] memory proof = new bytes32[](depth);
        bytes32[] memory nodes = whitelistLeaves;
        uint256 proofIndex = 0;
        uint256 levelSize = numLeaves;
        uint256 nodeIndex = index;

        // 从底层开始往上构建证明路径
        while(levelSize > 1) {
            bytes32[] memory nextLevel = new bytes32[]((levelSize + 1) / 2);
            
            for(uint256 i = 0; i < levelSize; i += 2) {
                if(i + 1 < levelSize) {
                    if(i == nodeIndex || i + 1 == nodeIndex) {
                        uint256 proofNodeIndex = (i == nodeIndex) ? i + 1 : i;
                        proof[proofIndex++] = nodes[proofNodeIndex];
                    }
                    nextLevel[i / 2] = hashPair(nodes[i], nodes[i + 1]);
                } else {
                    nextLevel[i / 2] = nodes[i];
                }
            }
            
            nodes = nextLevel;
            levelSize = (levelSize + 1) / 2;
            nodeIndex = nodeIndex / 2;
        }

        // 验证生成的证明是否正确
        bytes32 computedRoot = leaf;
        uint256 realProofLength = 0;
        for(uint256 i = 0; i < proof.length; i++) {
            if(proof[i] != bytes32(0)) {
                computedRoot = hashPair(computedRoot, proof[i]);
                realProofLength++;
            }else 
                break;
        }

        if (realProofLength < proof.length) {
            bytes32[] memory realProof = new bytes32[](realProofLength);
            // 创建新数组，移除后面的0元素
            for (uint256 i = 0; i < realProofLength; i++)
                realProof[i] = proof[i];
            delete proof;
            return realProof;
        }
         
        require(computedRoot == merkleRoot, "Invalid proof generated");

        return proof;
    }
    
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b 
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
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
