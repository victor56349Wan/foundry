// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract IDO is Ownable(msg.sender), ReentrancyGuard {
    IERC20 public token;
    uint256 public totalIDOtokenAmount;         // 预售代币总量
    uint256 public tokenPrice;          // 预售价格 (wei/token)
    uint256 public minEthTarget;        // 最低募集目标
    uint256 public maxEthCap;           // 最高募集上限
    uint256 public minEthPerUser;       // 单笔最低参与额
    uint256 public maxEthPerUser;       // 单地址最高参与额
    uint256 public endTime;             // 结束时间
    uint256 public totalEthRaised;      // 总募集金额
    bool public isFinalized;            // 是否已结束
    bool public isSuccessful;           // 是否成功

    mapping(address => uint256) public contributions;  // 用户贡献记录
    mapping(address => bool) public hasClaimed;       // 是否已领取

    event SaleStarted(address token, uint256 amount, uint256 price);
    event Contributed(address contributor, uint256 amount);
    event Claimed(address user, uint256 amount);
    event Refunded(address user, uint256 amount);
    event SaleFinalized(bool successful, uint256 totalRaised);

    function startSale(
        address _token,
        uint256 _tokenAmount,
        uint256 _tokenPrice,
        uint256 _minEthTarget,
        uint256 _maxEthCap,
        uint256 _minEthPerUser,
        uint256 _maxEthPerUser,
        uint256 _duration
    ) external onlyOwner {
        require(_token != address(0), "Invalid token");
        require(_tokenAmount > 0, "Invalid token amount");
        require(_tokenPrice > 0, "Invalid token price");
        require(_maxEthCap >= _minEthTarget, "Invalid eth caps");
        require(_maxEthPerUser >= _minEthPerUser, "Invalid user limits");

        token = IERC20(_token);
        totalIDOtokenAmount = _tokenAmount;
        tokenPrice = _tokenPrice;
        minEthTarget = _minEthTarget;
        maxEthCap = _maxEthCap;
        minEthPerUser = _minEthPerUser;
        maxEthPerUser = _maxEthPerUser;
        endTime = block.timestamp + _duration;

        require(
            token.transferFrom(msg.sender, address(this), _tokenAmount),
            "Token transfer failed"
        );
        
        emit SaleStarted(_token, _tokenAmount, _tokenPrice);
    }

    function contribute() external payable nonReentrant {
        require(block.timestamp < endTime, "Sale ended");
        require(!isFinalized, "Sale finalized");
        require(msg.value >= minEthPerUser, "Below min contribution");
        require(
            contributions[msg.sender] + msg.value <= maxEthPerUser,
            "Exceeds max contribution"
        );
        require(
            totalEthRaised + msg.value <= maxEthCap,
            "Exceeds max cap"
        );

        contributions[msg.sender] += msg.value;
        totalEthRaised += msg.value;

        emit Contributed(msg.sender, msg.value);
    }

    function finalize() external {
        require(block.timestamp >= endTime || totalEthRaised >= maxEthCap, "Too early");
        require(!isFinalized, "Already finalized");

        isFinalized = true;
        isSuccessful = totalEthRaised >= minEthTarget;

        emit SaleFinalized(isSuccessful, totalEthRaised);
    }

    function claim() external nonReentrant {
        require(isFinalized, "Not finalized");
        require(!hasClaimed[msg.sender], "Already claimed");
        require(contributions[msg.sender] > 0, "Nothing to claim");

        hasClaimed[msg.sender] = true;
        
        if (isSuccessful) {
            // 计算应得代币数量
            uint256 tokenAmount = totalIDOtokenAmount *  contributions[msg.sender] / totalEthRaised;
            require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");
            emit Claimed(msg.sender, tokenAmount);
        } else {
            // 退还 ETH
            uint256 refundAmount = contributions[msg.sender];
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "Refund failed");
            emit Refunded(msg.sender, refundAmount);
        }
    }

    function withdrawETH() external onlyOwner {
        require(isFinalized && isSuccessful, "Cannot withdraw");
        require(address(this).balance > 0, "Nothing to withdraw");
        
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
}
