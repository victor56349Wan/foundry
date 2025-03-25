// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../tokens/RNT.sol";
import "../tokens/EsRNT.sol";

contract StakingPool is ReentrancyGuard {
    RNT public rnt;
    EsRNT public esRnt;
    
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastUpdateTime;
    }
    
    mapping(address => UserInfo) public userInfo;
    
    uint256 public constant REWARD_PER_DAY_PER_RNT = 1; // 1 esRNT per RNT per day
    
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 reward);
    
    constructor(address _rnt, address _esRnt) {
        rnt = RNT(_rnt);
        esRnt = EsRNT(_esRnt);
    }
    
    function calculateUnclaimedReward(address user) public view returns (uint256) {
        UserInfo storage info = userInfo[user];
        if (info.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - info.lastUpdateTime;
        return (info.amount * timeElapsed * REWARD_PER_DAY_PER_RNT) / 1 days;
    }
    
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        
        // Claim pending rewards first
        claimReward();
        
        rnt.transferFrom(msg.sender, address(this), amount);
        
        UserInfo storage info = userInfo[msg.sender];
        info.amount += amount;
        info.lastUpdateTime = block.timestamp;
        
        emit Stake(msg.sender, amount);
    }
    
    function unstake(uint256 amount) external nonReentrant {
        UserInfo storage info = userInfo[msg.sender];
        require(amount > 0 && amount <= info.amount, "Invalid amount");
        
        // Claim pending rewards first
        claimReward();
        
        info.amount -= amount;
        info.lastUpdateTime = block.timestamp;
        
        rnt.transfer(msg.sender, amount);
        
        emit Unstake(msg.sender, amount);
    }
    
    function claimReward() public {
        uint256 reward = calculateUnclaimedReward(msg.sender);
        if (reward > 0) {
            UserInfo storage info = userInfo[msg.sender];
            info.lastUpdateTime = block.timestamp;
            esRnt.mint(msg.sender, reward);
            emit ClaimReward(msg.sender, reward);
        }
    }

    // 添加 getter 函数
    function getUserStakedAmount(address user) external view returns (uint256) {
        return userInfo[user].amount;
    }

    function getUserLastUpdateTime(address user) external view returns (uint256) {
        return userInfo[user].lastUpdateTime;
    }
}