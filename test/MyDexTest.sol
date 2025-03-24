// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MyDex/MyDex.sol";
import "../src/MyDex/DexFactory.sol";
import "../src/MyDex/DexPair.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 模拟 USDT 代币
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {
        _mint(msg.sender, 10000 * 10**18);
    }
}

contract DexPairTest is Test {
    MyDex dex;
    DexFactory factory;
    DexPair pair;
    MockUSDT usdt;
    address feeTo = makeAddr("FeeReceiver");
    address user = makeAddr("user");    
    address nonFactory = makeAddr("nonFactory");

    function setUp() public {
        // 部署 Factory 和 MyDex
        factory = new DexFactory(feeTo);
        dex = new MyDex(address(factory));
        
        // 部署 USDT
        usdt = new MockUSDT();
        
        // 创建并初始化 Pair，添加流动性
        address payable pairAddr = factory.createPair(address(usdt));
        pair = DexPair(pairAddr);
        
        vm.deal(address(this), 10 ether);
        usdt.approve(pairAddr, 1000 * 10**18);
        usdt.transfer(pairAddr, 1000 * 10**18);
        pair.addLiquidity{value: 1 ether}();

        // 给用户分配资金
        vm.deal(user, 10 ether);
        usdt.transfer(user, 1000 * 10**18);

    }

    // 测试 sellETH 成功
    function testSellETHSuccess() public {
        vm.startPrank(user);
        uint256 ethAmount = 0.1 ether;
        uint256 minBuyAmount = 90 * 10**18;
        uint256 feeToBalanceBefore = feeTo.balance;
        uint256 userUSDTBefore = usdt.balanceOf(user);

        dex.sellETH{value: ethAmount}(address(usdt), minBuyAmount);

        uint256 amountOut = usdt.balanceOf(user) - userUSDTBefore;
        assertGt(amountOut, minBuyAmount);
        assertEq(feeTo.balance - feeToBalanceBefore, (ethAmount * 3) / 1000); // 0.3% 费用
        vm.stopPrank();
    }

    // 测试 buyETH 成功
    function testBuyETHSuccess() public {
        vm.startPrank(user);
        uint256 sellAmount = 200 * 10**18;
        uint256 minBuyAmount = 0.05 ether;
        usdt.approve(address(dex), sellAmount);
        uint256 feeToUSDTBefore = usdt.balanceOf(feeTo);
        uint256 userETHBefore = user.balance;

        dex.buyETH(address(usdt), sellAmount, minBuyAmount);

        uint256 amountOut = user.balance - userETHBefore;
        assertGt(amountOut, minBuyAmount);
        assertEq(usdt.balanceOf(feeTo) - feeToUSDTBefore, (sellAmount * 3) / 1000); // 0.3% 费用
        vm.stopPrank();
    }

    // 测试 sellETH 失败：无流动性
    function testSellETHNoLiquidity() public {
        // 创建一个新的 MyDex 和 Factory，不添加流动性
        DexFactory newFactory = new DexFactory(feeTo);
        MyDex newDex = new MyDex(address(newFactory));
        
        vm.prank(user);
        vm.expectRevert("Pair does not exist");
        newDex.sellETH{value: 0.1 ether}(address(usdt), 90 * 10**18);
    }

    // 测试 buyETH 失败：无流动性
    function testBuyETHNoLiquidity() public {
        DexFactory newFactory = new DexFactory(feeTo);
        MyDex newDex = new MyDex(address(newFactory));
        
        vm.startPrank(user);
        usdt.approve(address(newDex), 200 * 10**18);
        vm.expectRevert("Pair does not exist");
        newDex.buyETH(address(usdt), 200 * 10**18, 0.05 ether);
        vm.stopPrank();
    }

    // 测试 sellETH 失败：输出不足
    function testSellETHInsufficientOutput() public {
        vm.prank(user);
        uint256 ethAmount = 0.1 ether;
        uint256 minBuyAmount = 1000 * 10**18; // 过高要求
        vm.expectRevert("Insufficient output amount");
        dex.sellETH{value: ethAmount}(address(usdt), minBuyAmount);
    }

    // 测试 buyETH 失败：输出不足
    function testBuyETHInsufficientOutput() public {
        vm.startPrank(user);
        uint256 sellAmount = 200 * 10**18;
        uint256 minBuyAmount = 0.2 ether; // 过高要求
        usdt.approve(address(dex), sellAmount);
        vm.expectRevert("Insufficient output amount");
        dex.buyETH(address(usdt), sellAmount, minBuyAmount);
        vm.stopPrank();
    }

    // 测试 sellETH 失败：零输入
    function testSellETHZeroInput() public {
        vm.prank(user);
        vm.expectRevert("Must send ETH");
        dex.sellETH{value: 0}(address(usdt), 90 * 10**18);
    }

    // 测试 buyETH 失败：零输入
    function testBuyETHZeroInput() public {
        vm.startPrank(user);
        usdt.approve(address(dex), 0);
        vm.expectRevert("Invalid sell amount");
        dex.buyETH(address(usdt), 0, 0.05 ether);
        vm.stopPrank();
    }

    receive() external payable {}
}