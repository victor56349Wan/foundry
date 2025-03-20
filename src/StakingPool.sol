// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RewardToken.sol";

contract StakingPool is ReentrancyGuard, Ownable(msg.sender) {
    RewardToken public rewardToken; // 改为RewardToken类型
    uint256 public rewardPerBlock; // 每个区块的奖励数量（单位：wei）
    uint256 public totalStaked; // 池子总质押量（ETH）
    uint256 public lastUpdateBlock; // 上次更新奖励的区块号

    // 用户质押信息
    struct StakeInfo {
        uint256 amount; // 质押的 ETH 数量
        uint256 startBlock; // 开始质押的区块号
        uint256 rewardDebt; // 已分配但未领取的奖励债务
    }

    mapping(address => StakeInfo) public stakes; // 用户地址 -> 质押信息
    uint256 public accumulatedRewardPerShare; // 每单位质押量的累积奖励（精度放大）

    // 精度因子，避免浮点运算
    uint256 public constant PRECISION = 1e18;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardPerBlockUpdated(uint256 newRewardPerBlock);

    constructor(uint256 _rewardPerBlock) {
        rewardToken = new RewardToken();
        rewardPerBlock = _rewardPerBlock;
        lastUpdateBlock = block.number;
    }

    // 更新池子的奖励累积点
    function updatePool() public {
        if (block.number <= lastUpdateBlock || totalStaked == 0) {
            lastUpdateBlock = block.number;
            return;
        }

        // 计算从上次更新到当前区块的奖励总量
        uint256 blocksElapsed = block.number - lastUpdateBlock;
        uint256 reward = blocksElapsed * rewardPerBlock;

        // 更新每单位质押量的累积奖励
        accumulatedRewardPerShare += (reward * PRECISION) / totalStaked;
        lastUpdateBlock = block.number;
    }

    // 质押 ETH
    function stake() external payable nonReentrant {
        require(msg.value > 0, "Must stake some ETH");

        updatePool(); // 更新池子状态

        StakeInfo storage userStake = stakes[msg.sender];
        if (userStake.amount > 0) {
            // 如果已有质押，计算并累积奖励
            uint256 pending = (userStake.amount * accumulatedRewardPerShare) / PRECISION - userStake.rewardDebt;
            if (pending > 0) {
                safeRewardTransfer(msg.sender, pending);
            }
        }

        // 更新用户质押信息
        userStake.amount += msg.value;
        userStake.startBlock = block.number;
        userStake.rewardDebt = (userStake.amount * accumulatedRewardPerShare) / PRECISION;

        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    // 解质押并领取奖励
    function unstake(uint256 amount) external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient staked amount");
        require(amount > 0, "Amount must be greater than 0");

        updatePool(); // 更新池子状态

        // 计算用户应得奖励
        uint256 pending = (userStake.amount * accumulatedRewardPerShare) / PRECISION - userStake.rewardDebt;
        if (pending > 0) {
            safeRewardTransfer(msg.sender, pending);
        }

        // 更新用户质押信息
        userStake.amount -= amount;
        userStake.rewardDebt = (userStake.amount * accumulatedRewardPerShare) / PRECISION;
        if (userStake.amount == 0) {
            delete stakes[msg.sender]; // 清空记录
        }

        totalStaked -= amount;

        // 返还 ETH
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit Unstaked(msg.sender, amount, pending);
    }

    // 获取用户当前未领取的奖励
    function getPendingReward(address user) external view returns (uint256) {
        StakeInfo memory userStake = stakes[user];
        if (userStake.amount == 0 || totalStaked == 0) {
            return 0;
        }

        uint256 tempAccumulatedRewardPerShare = accumulatedRewardPerShare;
        if (block.number > lastUpdateBlock) {
            uint256 blocksElapsed = block.number - lastUpdateBlock;
            uint256 reward = blocksElapsed * rewardPerBlock;
            tempAccumulatedRewardPerShare += (reward * PRECISION) / totalStaked;
        }

        return (userStake.amount * tempAccumulatedRewardPerShare) / PRECISION - userStake.rewardDebt;
    }

    // 设置每个区块的奖励数量（仅管理员）
    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
        emit RewardPerBlockUpdated(_rewardPerBlock);
    }

    // 安全转移改为铸造奖励
    function safeRewardTransfer(address to, uint256 amount) internal {
        rewardToken.mint(to, amount);
    }

    // 接收 ETH 的回退函数
    receive() external payable {}
}