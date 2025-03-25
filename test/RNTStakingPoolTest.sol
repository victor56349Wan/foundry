// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import "../src/RNTStaking/tokens/RNT.sol";
import "../src/RNTStaking/tokens/EsRNT.sol";
import "../src/RNTStaking/core/RNTStakingPool.sol";

contract RNTStakingPoolTest is Test {
    RNT public rnt;
    EsRNT public esRnt;
    StakingPool public pool;
    
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    
    function setUp() public {
        // 部署合约
        rnt = new RNT();
        esRnt = new EsRNT(address(rnt));
        // 设置权限
        rnt.transferOwnership(address(esRnt));

        pool = new StakingPool(address(rnt), address(esRnt));
        
        // 设置权限
        esRnt.transferOwnership(address(pool));
        
        // 向测试用户转账RNT
        rnt.transfer(alice, 1000e18);
        rnt.transfer(bob, 1000e18);
        
        // 用户授权
        vm.startPrank(alice);
        rnt.approve(address(pool), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        rnt.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function test_SingleUserStake() public {
        vm.startPrank(alice);
        
        // 质押100个RNT
        pool.stake(100e18);
        assertEq(pool.getUserStakedAmount(alice), 100e18);
        
        // 等待1天
        skip(1 days);
        
        // 验证奖励计算
        uint256 reward = pool.calculateUnclaimedReward(alice);
        assertEq(reward, 100e18); // 每天每个RNT奖励1个esRNT
        
        // 领取奖励
        pool.claimReward();
        assertEq(esRnt.balanceOf(alice), 100e18);
        
        vm.stopPrank();
    }
    
    function test_MultiUserStaking() public {
        // Alice质押100 RNT
        vm.prank(alice);
        pool.stake(100e18);
        
        // Bob质押200 RNT
        vm.prank(bob);
        pool.stake(200e18);
        
        // 等待1天
        skip(1 days);
        
        // 验证两个用户的奖励
        assertEq(pool.calculateUnclaimedReward(alice), 100e18);
        assertEq(pool.calculateUnclaimedReward(bob), 200e18);
        
        // 两个用户都领取奖励
        vm.prank(alice);
        pool.claimReward();
        
        vm.prank(bob);
        pool.claimReward();
        
        assertEq(esRnt.balanceOf(alice), 100e18);
        assertEq(esRnt.balanceOf(bob), 200e18);
    }
    
    function test_UnstakeAndReward() public {
        vm.startPrank(alice);
        
        // 质押100 RNT
        pool.stake(100e18);
        
        // 等待半天
        skip(12 hours);
        
        // 解质押50 RNT
        pool.unstake(50e18);
        
        // 再等待半天
        skip(12 hours);
        
        // 验证总奖励：
        // 前12小时: 100 RNT * 0.5 day = 50 esRNT
        // 后12小时: 50 RNT * 0.5 day = 25 esRNT
        uint256 unClaimedReward = pool.calculateUnclaimedReward(alice);
        uint256 totalReward = esRnt.balanceOf(alice) + unClaimedReward;
        assertApproxEqAbs(totalReward, 75e18, 1e15); // 允许0.001的误差
        
        vm.stopPrank();
    }
    
    function test_EsRNTConversion() public {
        vm.startPrank(alice);
        
        // 质押并等待1天赚取esRNT
        pool.stake(100e18);
        skip(1 days);
        pool.claimReward();
        
        uint256 initialRntBalance = rnt.balanceOf(alice);
        
        // 等待15天 (锁定期的一半)
        skip(15 days);
        
        // 转换esRNT到RNT
        esRnt.convert();
        
        // 验证获得的RNT数量 (应该是大约50% 因为只过了一半锁定期)
        uint256 finalRntBalance = rnt.balanceOf(alice);
        uint256 receivedRnt = finalRntBalance - initialRntBalance;
        assertApproxEqRel(receivedRnt, 50e18, 0.01e18); // 允许1%的误差
        
        vm.stopPrank();
    }

    function test_CrossUserInteractions() public {
        // Alice先质押
        vm.prank(alice);
        pool.stake(100e18);
        
        skip(1 days);
        
        // Bob后质押
        vm.prank(bob);
        pool.stake(200e18);
        
        skip(1 days);
        
        // Alice解质押一半
        vm.prank(alice);
        pool.unstake(50e18);
        
        skip(1 days);
        
        // 验证两个用户的最终奖励
        vm.prank(alice);
        pool.claimReward();
        
        vm.prank(bob);
        pool.claimReward();
        
        // Alice的奖励：2天100 RNT + 1天50 RNT
        // Bob的奖励：2天200 RNT
        assertApproxEqAbs(esRnt.balanceOf(alice), 250e18, 1e15);
        assertApproxEqAbs(esRnt.balanceOf(bob), 400e18, 1e15);
    }
}
