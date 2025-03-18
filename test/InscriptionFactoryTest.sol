pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/InscriptionFactory.sol";
import "../src/InscriptionToken.sol";

contract InscriptionFactoryTest is Test {
    InscriptionFactory public factory;
    address public feeCollector;
    address public deployer;
    
    function setUp() public {
        feeCollector = makeAddr("feeCollector");
        deployer = makeAddr("deployer");
        
        vm.startPrank(deployer);
        factory = new InscriptionFactory(feeCollector);
        vm.stopPrank();
    }

    function testDeployAndMint() public {
        // 部署新的铭文代币
        string memory symbol = "TEST";
        uint256 totalSupply = 1000 ether;
        uint256 perMint = 10 ether;
        uint256 price = 1000 wei;
        
        vm.startPrank(deployer);
        address tokenAddr = factory.deployInscription(
            symbol,
            totalSupply,
            perMint,
            price
        );
        vm.stopPrank();
        
        // 验证部署结果
        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.perMint(), perMint);
        assertEq(token.price(), price);
        
        // 测试铸造
        address buyer = makeAddr("buyer");
        vm.deal(buyer, (price * perMint/1 ether) + 1 ether);
        
        uint256 feeCollectorBalanceBefore = feeCollector.balance;
        uint256 deployerBalanceBefore = deployer.balance;
        
        vm.startPrank(buyer);
        factory.mintInscription{value: price * perMint/1 ether}(tokenAddr);
        vm.stopPrank();
        
        // 验证铸造结果
        assertEq(token.balanceOf(buyer), perMint);
        assertEq(token.minted(), perMint);
        
        // 验证费用分配
        uint256 fee = (price * perMint/1 ether * factory.FEE_RATE()) / 10000;
        assertEq(feeCollector.balance - feeCollectorBalanceBefore, fee);
        assertEq(deployer.balance - deployerBalanceBefore, price * perMint/1 ether - fee);
    }

    function testMintExceedsTotalSupply() public {
        // 部署代币，总供应量等于单次铸造量
        uint256 totalSupply = 10 ether;
        uint256 perMint = 10 ether;
        uint256 price = 1000 wei;        
        vm.startPrank(deployer);
        address tokenAddr = factory.deployInscription(
            "TEST",
            totalSupply,
            perMint,
            price
        );
        vm.stopPrank();
        
        // 第一次铸造成功
        address buyer = makeAddr("buyer");
        vm.deal(buyer, 1 ether);
        vm.prank(buyer);
        factory.mintInscription{value: price * perMint/1 ether}(tokenAddr);
        
        // 第二次铸造应该失败
        address buyer2 = makeAddr("buyer2");
        vm.deal(buyer2, 1 ether);
        vm.startPrank(buyer2);
        vm.expectRevert("Exceeds total supply");
        factory.mintInscription{value: price * perMint/1 ether}(tokenAddr);
        vm.stopPrank();
    }
}
