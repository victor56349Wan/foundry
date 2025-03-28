// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/FlashLoan/TokenA.sol";
import "../src/FlashLoan/TokenB.sol";
import "../src/FlashLoan/DexFactory.sol";
import "../src/FlashLoan/DexPair.sol";
import "../src/FlashLoan/FlashSwap.sol";

contract FlashSwapTest is Test {
    TokenA tokenA;
    TokenB tokenB;
    DexFactory dexA;
    DexFactory dexB;
    FlashSwap flashSwap;
    address user = address(0x123);

    function setUp() public {
        // 部署代币
        tokenA = new TokenA();
        tokenB = new TokenB();

        // 部署两个 DEX
        dexA = new DexFactory();
        dexB = new DexFactory();

        // 部署 FlashSwap
        flashSwap = new FlashSwap(address(dexA), address(dexB));

        // 创建交易对
        address pairA = dexA.createPair(address(tokenA), address(tokenB));
        address pairB = dexB.createPair(address(tokenA), address(tokenB));

        // 添加流动性并设置价差
        tokenA.approve(pairA, 2000 * 10**18);
        tokenB.approve(pairA, 1000 * 10**18);

        tokenA.approve(pairB, 1000 * 10**18);
        tokenB.approve(pairB, 2000 * 10**18);

        DexPair(pairB).addLiquidity(address(tokenA), address(tokenB), 1000 * 10**18, 2000 * 10**18); // PoolB: 1000 A, 2000 B (1A = 2B)
        DexPair(pairA).addLiquidity(address(tokenA), address(tokenB), 2000 * 10**18, 1000 * 10**18); // PoolA: 2000 A, 1000 B (1A = 0.5B)
        /**
        PoolA: 2000 A, 1000 B (1A = 0.5B)
        PoolB: 1000 A, 2000 B (1A = 2B)
        from 
         */
        // 给用户分配代币
        vm.deal(user, 10 ether);
        tokenA.transfer(user, 100 * 10**18);
        tokenB.transfer(user, 100 * 10**18);
    }

    function testFlashSwapSuccess() public {
        vm.startPrank(user);
        uint256 amountA = 500 * 10**18; // 借 100 TokenA
        uint256 userBalanceBefore = tokenB.balanceOf(user);

        flashSwap.executeFlashSwap(address(tokenA), address(tokenB), amountA);

        uint256 profit = tokenB.balanceOf(user) - userBalanceBefore;
        assertGt(profit, 0, "No profit made");
        console.log("Profit in TokenB:", profit / 10**18);
        vm.stopPrank();
    }
}