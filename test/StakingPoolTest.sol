// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console, console2} from "forge-std/Test.sol";
import {StakingPool} from "../src/StakingPool.sol";
import {RewardToken} from "../src/RewardToken.sol";

contract StakingPoolTest is Test {
    StakingPool public stakingPool;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    uint256 public constant REWARD_PER_BLOCK = 10 ether; // 1 token per block

    function setUp() public {
        // 部署质押池合约
        stakingPool = new StakingPool(REWARD_PER_BLOCK);
        
        // 给测试账户一些ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function test_Deployment() public view{
        assertEq(stakingPool.rewardPerBlock(), REWARD_PER_BLOCK);
        assertEq(stakingPool.totalStaked(), 0);
    }

    function test_Stake() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        assertEq(stakingPool.totalStaked(), 1 ether);
        assertEq(address(stakingPool).balance, 1 ether);
        vm.stopPrank();
    }

    function test_Stake_With_BalanceOf() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        assertEq(stakingPool.balanceOf(alice), 1 ether);
        vm.stopPrank();
    }

    function test_Unstake() public {
        // 先质押
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        
        // 等待一些区块以累积奖励
        vm.roll(block.number + 10);
        
        // 解质押
        uint256 balanceBefore = alice.balance;
        stakingPool.unstake(1 ether);
        assertEq(alice.balance, balanceBefore + 1 ether);
        assertEq(stakingPool.totalStaked(), 0);
        
        // 检查是否收到奖励代币
        RewardToken rewardToken = stakingPool.rewardToken();
        assertTrue(rewardToken.balanceOf(alice) > 0);
        vm.stopPrank();
    }

    function test_RewardCalculation() public {
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        
        uint256 blocks = 10;
        vm.roll(block.number + blocks);
        
        // 预期奖励应该是块数 * 每块奖励
        uint256 expectedReward = blocks * REWARD_PER_BLOCK;
        uint256 pendingReward = stakingPool.earned(alice);
        assertEq(pendingReward, expectedReward);
        vm.stopPrank();
    }

    function test_Claim() public {
        // 先质押
        vm.startPrank(alice);
        stakingPool.stake{value: 1 ether}();
        
        // 等待10个区块
        vm.roll(block.number + 10);
        
        // 查看待领取奖励
        uint256 pendingBefore = stakingPool.earned(alice);
        assertTrue(pendingBefore > 0);
        
        // 领取奖励
        stakingPool.claim();
        
        // 验证奖励已领取
        assertEq(stakingPool.earned(alice), 0);
        assertEq(stakingPool.rewardToken().balanceOf(alice), pendingBefore);
        vm.stopPrank();
    }

    function test_MultipleStakers() public {
        // Alice质押1 ETH
        vm.prank(alice);
        stakingPool.stake{value: 1 ether}();
        
        vm.roll(block.number + 5);
        
        // Bob质押2 ETH
        vm.prank(bob);
        stakingPool.stake{value: 2 ether}();
        
        vm.roll(block.number + 5);
        
        // 验证两个用户都能收到奖励
        assertTrue(stakingPool.earned(alice) > 0);
        assertTrue(stakingPool.earned(bob) > 0);
    }

    function testMultipleUsers() public {
        vm.startPrank(user1);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();

        vm.roll(block.number + 10); // 快进 10 个区块
        vm.startPrank(user2);
        stakingPool.stake{value: 2 ether}();
        vm.stopPrank();

        vm.roll(block.number + 10); // 快进 10 个区块
        vm.startPrank(user2);
        uint256 pendingReward2 = stakingPool.earned(user2);
        stakingPool.claim();
        assertEq(stakingPool.rewardToken().balanceOf(user2), pendingReward2);
        stakingPool.unstake(2 ether);
        vm.stopPrank();

        vm.roll(block.number + 10); // 快进 10 个区块
        vm.startPrank(user1);
        uint256 pendingReward1 = stakingPool.earned(user1);
        stakingPool.claim();
        assertEq(stakingPool.rewardToken().balanceOf(user1), pendingReward1);
        stakingPool.unstake(2 ether);
        assertGt(pendingReward1, pendingReward2); // user1 质押时间更长，奖励更多
        vm.stopPrank();
    }

    receive() external payable {}
}
