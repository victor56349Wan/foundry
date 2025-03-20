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
        uint256 pendingReward = stakingPool.getPendingReward(alice);
        assertEq(pendingReward, expectedReward);
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
        assertTrue(stakingPool.getPendingReward(alice) > 0);
        assertTrue(stakingPool.getPendingReward(bob) > 0);
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
        stakingPool.unstake(2 ether);
        RewardToken rewardToken = stakingPool.rewardToken();
        uint256 reward2 = rewardToken.balanceOf(user2);
        console.log("reward2", reward2);
        assertGt(reward2, 0);
        vm.stopPrank();

        vm.roll(block.number + 10); // 快进 10 个区块
        vm.startPrank(user1);
        stakingPool.unstake(2 ether);
        uint256 reward1 = rewardToken.balanceOf(user1);
        console.log("reward1", reward1);
        assertGt(reward1, reward2); // user1 质押时间更长，奖励更多
        vm.stopPrank();
    }

    receive() external payable {}
}
