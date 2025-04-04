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

    event PositionInfo(string message, address user, int256 pnl);

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

    function checkPnLAndBalance(
        address user,
        uint256 initialBalance,
        string memory message
    ) internal {
        int256 pnl = dex.calculatePnL(user);
        uint256 finalBalance = usdc.balanceOf(user);
        assertEq(
            int256(finalBalance) - int256(initialBalance),
            pnl,
            string.concat(message, " - Balance change should match PnL")
        );
        emit PositionInfo(message, user, pnl);
    }

    function testLongPositionOpenAndClose() public {
        vm.startPrank(alice);
        uint256 initialBalance = usdc.balanceOf(alice);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true); // 2倍杠杆做多
        
        int256 PnL = dex.calculatePnL(alice);
        console.log('PnL right after open long position:\t', PnL);
        // 由于AMM滑点影响以及千分之三手续，允许在保证金+-0.7%范围内波动
        assertTrue(PnL > -7 ether && PnL < 7 ether); // 1000 * 1% = 1
        
        dex.closePosition();
        uint256 finalBalance = usdc.balanceOf(alice);
        // 验证账户余额变化与PnL一致
        assertEq(int256(finalBalance) - int256(initialBalance), PnL);
        vm.stopPrank();
    }

    function testShortPositionOpenAndClose() public {
        vm.startPrank(bob);
        uint256 initialBalance = usdc.balanceOf(bob);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, false); // 2倍杠杆做空
        
        int256 PnL = dex.calculatePnL(bob);
        console.log('PnL right after open short position:\t', PnL);
        // 由于AMM滑点影响以及千分之三手续，允许在保证金+-0.7%范围内波动
        assertTrue(PnL > -7 ether && PnL < 7 ether); // 1000 * 1% = 10
        
        dex.closePosition();
        uint256 finalBalance = usdc.balanceOf(bob);
        // 验证账户余额变化与PnL一致
        assertEq(int256(finalBalance) - int256(initialBalance), PnL);
        vm.stopPrank();
    }

    function testMultipleUsersLong() public {
        // Alice做多
        vm.startPrank(alice);
        uint256 aliceInitialBalance = usdc.balanceOf(alice);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true);
        vm.stopPrank();
        console.log("Alice PnL right after open long position:\t", dex.calculatePnL(alice));
        
        // Bob做多
        vm.startPrank(bob);
        uint256 bobInitialBalance = usdc.balanceOf(bob);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true);
        vm.stopPrank();
        
        // Alice先关仓
        int256 alicePnL = dex.calculatePnL(alice);
        console.log("Alice PnL after Bob long the same position:\t", dex.calculatePnL(alice));
        console.log("Bob PnL:\t", dex.calculatePnL(bob));
        vm.prank(alice);
        dex.closePosition();
        uint256 aliceFinalBalance = usdc.balanceOf(alice);
        assertEq(int256(aliceFinalBalance) - int256(aliceInitialBalance), alicePnL);

        // Bob后关仓
        int256 bobPnL = dex.calculatePnL(bob);
        vm.prank(bob);
        dex.closePosition();
        uint256 bobFinalBalance = usdc.balanceOf(bob);
        assertEq(int256(bobFinalBalance) - int256(bobInitialBalance), bobPnL);
    }

    function testMultipleUsersShort() public {
        // Alice做空
        vm.startPrank(alice);
        uint256 aliceInitialBalance = usdc.balanceOf(alice);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, false);
        vm.stopPrank();
        console.log("Alice PnL right after open short position:\t", dex.calculatePnL(alice));
        
        // Bob做空
        vm.startPrank(bob);
        uint256 bobInitialBalance = usdc.balanceOf(bob);
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, false);
        vm.stopPrank();
        
        // Alice先关仓
        int256 alicePnL = dex.calculatePnL(alice);
        console.log("Alice PnL after Bob short the same position:\t", dex.calculatePnL(alice));
        console.log("Bob PnL:\t", dex.calculatePnL(bob));
        vm.prank(alice);
        dex.closePosition();
        uint256 aliceFinalBalance = usdc.balanceOf(alice);
        assertEq(int256(aliceFinalBalance) - int256(aliceInitialBalance), alicePnL);

        // Bob后关仓
        int256 bobPnL = dex.calculatePnL(bob);
        vm.prank(bob);
        dex.closePosition();
        uint256 bobFinalBalance = usdc.balanceOf(bob);
        assertEq(int256(bobFinalBalance) - int256(bobInitialBalance), bobPnL);
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
        uint256 bobInitialBalance = usdc.balanceOf(bob);
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

        // 记录Bob被清算前的PnL和David的初始余额
        int256 bobPnL = dex.calculatePnL(bob);
        uint256 davidInitialBalance = usdc.balanceOf(david);
        
        // 现在David应该能清算Bob但不能清算Alice
        vm.startPrank(david);
        dex.liquidatePosition(bob); // 应该成功
        uint256 bobFinalBalance = usdc.balanceOf(bob);
        uint256 davidFinalBalance = usdc.balanceOf(david);
        
        // 验证Bob的最终余额
        assertEq(int256(bobFinalBalance), int256(bobInitialBalance));
        
        // 验证David作为清算者获得的收益 = Bob仓位剩余的保证金
        int256 davidProfit = int256(davidFinalBalance) - int256(davidInitialBalance);
        assertTrue(davidProfit > 0, "Liquidator should get positive profit");
        assertEq(  davidProfit, (1000 ether + bobPnL) * 997 / 1000, "Liquidator profit should be 0.3% less than Bob's remaining margin");        

        console.log("Bod liquidated, Alice PnL:\t\t", dex.calculatePnL(alice));
        vm.stopPrank();

        // Frank加入做空, 导致Alice穿仓资不抵债, 清算失败
        vm.startPrank(frank);
        usdc.approve(address(dex), 5000 ether);
        dex.openPosition(1000 ether, 2, false);
        int256 alicePnL = dex.calculatePnL(alice);
        console.log("Frank short, Alice PnL:\t", dex.calculatePnL(alice));
        vm.expectRevert('No position');
        console.log("Bob PnL:\t", dex.calculatePnL(bob));
        vm.stopPrank();

        // David清算Bob, 提示无仓位
        vm.startPrank(david);
        vm.expectRevert('No position');
        dex.liquidatePosition(bob); // 无仓位提示

        // 记录Bob被清算前的PnL和David的初始余额
        alicePnL = dex.calculatePnL(alice);
        davidInitialBalance = usdc.balanceOf(david);
        
        // 资不抵债, 清算Alice失败
        vm.startPrank(david);
        vm.expectRevert('Not enough profit to liquidate');
        dex.liquidatePosition(alice); // 应该失败
        vm.stopPrank();

    }

    function testBoundaryConditions() public {
        vm.startPrank(alice);
        
        // 测试最小仓位
        usdc.approve(address(dex), 100 ether);
        dex.openPosition(100 ether, 2, true);
        dex.closePosition();
        // 测试最大杠杆
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 5, true);
        
        vm.stopPrank();
    }

    function testFeeCalculation() public {
        vm.startPrank(alice);
        uint256 initialBalance = usdc.balanceOf(alice);
        
        usdc.approve(address(dex), 1000 ether);
        dex.openPosition(1000 ether, 2, true);
        
        // 直接关仓检查手续费扣除
        dex.closePosition();
        
        uint256 finalBalance = usdc.balanceOf(alice);
        uint256 totalFee = initialBalance - finalBalance;
        
        // 验证总手续费在合理范围内 (开仓+平仓 = 0.6%)
        assertTrue(totalFee >= (1000 ether * 6 / 1000), "Fee too low");
        assertTrue(totalFee <= (1000 ether * 7 / 1000), "Fee too high");
        
        vm.stopPrank();
    }
}
