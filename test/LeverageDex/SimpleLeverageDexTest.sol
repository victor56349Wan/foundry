// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/LeverageDex/SimpleLeverageDex.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyUSDC is ERC20 {
    constructor() ERC20("MyUSDC", "USDC") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract SimpleLeverageDexTest is Test {
    SimpleLeverageDEX public dex;
    MyUSDC public usdc;
    address alice = address(1);
    address bob = address(2);
    address charlie = address(3);
    address david = address(4);
    address eve = address(5);
    address frank = address(6);

    function setUp() public {
        usdc = new MyUSDC();
        dex = new SimpleLeverageDEX(100 ether, 10000 ether, address(usdc)); // 初始价格 2000 USDC/ETH
        
        // 设置各个用户的初始USDC余额
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(david, 100 ether);
        vm.deal(eve, 100 ether);
        
        usdc.transfer(alice, 10000 ether);
        usdc.transfer(bob, 10000 ether);
        usdc.transfer(charlie, 100000 ether);
        usdc.transfer(david, 10000 ether);
        usdc.transfer(eve, 100000 ether);
        usdc.transfer(frank, 100000 ether);
    }

    function testLongPositionOpenAndClose() public {
        vm.startPrank(alice);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true); // 2倍杠杆做多
        
        int256 PnL = dex.calculatePnL(alice);
        console.log('PnL right after open long position:\t', PnL);
        // 由于AMM滑点影响以及千分之三手续，允许在保证金+-0.7%范围内波动
        assertTrue(PnL > -7 ether && PnL < 7 ether); // 1000 * 1% = 10
        
        dex.closePosition();
        vm.stopPrank();
    }

    function testShortPositionOpenAndClose() public {
        vm.startPrank(bob);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, false); // 2倍杠杆做空
        
        int256 PnL = dex.calculatePnL(bob);
        console.log('PnL right after open short position:\t', PnL);
        // 由于AMM滑点影响以及千分之三手续，允许在保证金+-0.7%范围内波动
        assertTrue(PnL > -7 ether && PnL < 7 ether); // 1000 * 1% = 10
        
        dex.closePosition();
        vm.stopPrank();
    }

    function testMultipleUsersLong() public {
        // Alice做多
        vm.startPrank(alice);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true);
        vm.stopPrank();
        console.log("Alice PnL right after open long position:\t", dex.calculatePnL(alice));
        // Bob做多
        vm.startPrank(bob);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true);
        vm.stopPrank();
        
        // Alice先关仓
        console.log("Alice PnL after Bob long the same position:\t", dex.calculatePnL(alice));
        console.log("Bob PnL:\t", dex.calculatePnL(bob));

        vm.prank(alice);
        dex.closePosition();

        // Bob后关仓
        vm.prank(bob);
        dex.closePosition();

    }

    function testLiquidationScenario() public {
        // Alice做多
        vm.startPrank(alice);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true);
        vm.stopPrank();
        
        console.log("Alice PnL:\t", dex.calculatePnL(alice));
        // Bob做多
        vm.startPrank(bob);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true);
        vm.stopPrank();
        
        console.log("Alice PnL:\t", dex.calculatePnL(alice));
        console.log("Bob PnL:\t", dex.calculatePnL(bob));

        // Charlie大仓位做空
        vm.startPrank(charlie);
        usdc.approve(address(dex), 5000 ether);
        dex.openPosition(1000 ether, 2, false);
        vm.stopPrank();

        console.log("Alice PnL:\t", dex.calculatePnL(alice));
        console.log("Bob PnL:\t", dex.calculatePnL(bob));

        // David尝试清算Bob（应该失败）
        vm.startPrank(david);
        vm.expectRevert("Not enough loss to liquidate");
        dex.liquidatePosition(bob);
        vm.stopPrank();
        console.log("Alice PnL:\t", dex.calculatePnL(alice));
        console.log("Bob PnL:\t", dex.calculatePnL(bob));
       
        // Eve再加入做空，进一步压低价格
        vm.startPrank(eve);
        usdc.approve(address(dex), 5000 ether);
        dex.openPosition(1000 ether, 2, false);
        vm.stopPrank();

        console.log("Eve short, Alice PnL:\t\t", dex.calculatePnL(alice));
        console.log("Bob PnL:\t", dex.calculatePnL(bob));

        
        // 现在David应该能清算Bob但不能清算Alice
        vm.startPrank(david);
        dex.liquidatePosition(bob); // 应该成功
        vm.expectRevert("Not enough loss to liquidate");
        dex.liquidatePosition(alice);
        vm.stopPrank();

        // Frank加入做空, 导致Alice穿仓资不抵债, 清算失败
        vm.startPrank(frank);
        usdc.approve(address(dex), 5000 ether);
        dex.openPosition(1000 ether, 2, false);
        console.log("Frank short, Alice PnL:\t", dex.calculatePnL(alice));
        vm.expectRevert('No open position');
        console.log("Bob PnL:\t", dex.calculatePnL(bob));

        // 现在David应该均不能清算Bob和Alice,失败提示不一样
        vm.startPrank(david);
        vm.expectRevert('No open position');
        dex.liquidatePosition(bob); // 无仓位提示
        vm.expectRevert('Not enough profit to liquidate');   // 资不抵债提示
        dex.liquidatePosition(alice);
        vm.stopPrank();

    }
}
