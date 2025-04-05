// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/Test.sol";

contract CallOptionToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public strikePrice;     // 行权价格（以支付代币计价）
    uint256 public expiryDate;      // 到期日时间戳
    address public paymentToken;    // 支付代币地址

    constructor(
        string memory name,
        string memory symbol,
        uint256 _strikePrice,
        uint256 _expiryDays,
        address _paymentToken
    ) ERC20(name, symbol) Ownable(msg.sender) {
        require(_paymentToken != address(0), "Invalid payment token");
        strikePrice = _strikePrice;
        expiryDate = block.timestamp + _expiryDays * 1 days;
        paymentToken = _paymentToken;
    }
    
    // 发行期权Token
    function mint() external payable {
        require(msg.value > 0, "Must send ETH");
        require(block.timestamp < expiryDate, "Option expired");
        
        // 1 ETH = 1 期权Token
        _mint(msg.sender, msg.value);
    }

    // 行权方法
    function exercise(uint256 amount) external nonReentrant {
        require(block.timestamp <= expiryDate, "Option expired");
        console.log("Option amount: ", amount);
        console.log("balanceOf: ", balanceOf(msg.sender));
        require(balanceOf(msg.sender) >= amount, "Insufficient option tokens");
        
        uint256 tokenRequired = (amount * strikePrice) / 1e18;
        
        // 获取支付代币合约实例
        IERC20 token = IERC20(paymentToken);
        
        // 检查用户代币余额
        require(token.balanceOf(msg.sender) >= tokenRequired, "Insufficient token balance");
        
        // 记录转账前余额
        uint256 beforeBalance = token.balanceOf(address(this));
        
        // 安全转移代币
        token.safeTransferFrom(msg.sender, address(this), tokenRequired);
        
        // 验证转账后余额
        uint256 afterBalance = token.balanceOf(address(this));
        require(afterBalance == beforeBalance + tokenRequired, "Token transfer amount mismatch");
        
        // 转移ETH
        _burn(msg.sender, amount);
        console.log("Contract ETH balance before transfer: ", address(this).balance);
        console.log("Transfer amount: ", amount);
        
        // 使用call而不是transfer发送ETH
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        console.log("Contract ETH balance after transfer: ", address(this).balance);
    }
    
    // 过期销毁
    function expire() external onlyOwner {
        require(block.timestamp > expiryDate, "Not expired yet");
        
        // 先销毁所有代币
        uint256 totalTokens = totalSupply();
        _burn(address(this), balanceOf(address(this)));
        
        // 如果还有ETH余额，返还给owner
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = payable(owner()).call{value: balance}("");
            require(success, "ETH transfer failed");
        }
    }
    
    // 查看合约ETH余额
    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    receive() external payable {}
}
