// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DexFactory.sol";
import "forge-std/Test.sol";
contract DexPair {
    address public factory;
    address public token; // ERC-20 代币（如 USDT）
    uint256 public reserveETH; // ETH 储备
    uint256 public reserveToken; // Token 储备

    uint256 constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event Mint(address indexed sender, uint256 amountETH, uint256 amountToken);
    event Burn(address indexed sender, uint256 amountETH, uint256 amountToken);
    event Swap(address indexed sender, uint256 amountETHIn, uint256 amountTokenIn, uint256 amountETHOut, uint256 amountTokenOut);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token) external {
        require(msg.sender == factory, "Only factory can initialize");
        require(token == address(0), "Already initialized");
        require(_token != address(0), "Invalid token address");
        token = _token;
    }
    // 添加流动性
    function addLiquidity() external payable returns (uint256 liquidity) {
        uint256 amountETH = msg.value;
        uint256 amountToken = IERC20(token).balanceOf(address(this)) - reserveToken;
        require(amountETH > 0 && amountToken > 0, "Invalid amounts");

        if (totalSupply == 0) {
            liquidity = sqrt(amountETH * amountToken) - MINIMUM_LIQUIDITY;
            balanceOf[address(0)] = MINIMUM_LIQUIDITY;
        } else {
            liquidity = min((amountETH * totalSupply) / reserveETH, (amountToken * totalSupply) / reserveToken);
        }

        reserveETH += amountETH;
        reserveToken += amountToken;
        totalSupply += liquidity;
        balanceOf[msg.sender] += liquidity;

        emit Mint(msg.sender, amountETH, amountToken);
        return liquidity;
    }

    // 移除流动性
    function removeLiquidity(uint256 liquidity) external returns (uint256 amountETH, uint256 amountToken) {
        require(liquidity > 0 && balanceOf[msg.sender] >= liquidity, "Insufficient liquidity");

        amountETH = (liquidity * reserveETH) / totalSupply;
        amountToken = (liquidity * reserveToken) / totalSupply;

        reserveETH -= amountETH;
        reserveToken -= amountToken;
        totalSupply -= liquidity;
        balanceOf[msg.sender] -= liquidity;

        (bool success, ) = msg.sender.call{value: amountETH}("");
        require(success, "ETH transfer failed");
        require(IERC20(token).transfer(msg.sender, amountToken), "Token transfer failed");

        emit Burn(msg.sender, amountETH, amountToken);
        return (amountETH, amountToken);
    }

    // 计算输出量（含 0.3% 费用）
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid inputs");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint256 amountInWithFee = amountIn * 997 / 1000; // 0.3% 费用
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;
        return numerator / denominator;
    }

    // Swap: ETH -> Token
    function swapETHToToken(uint256 minAmountOut, address to) external payable returns (uint256 amountOut) {
        uint256 amountIn = msg.value;
        require(amountIn > 0, "Invalid ETH amount");
        require(reserveETH > 0 && reserveToken > 0, "Insufficient liquidity");

        // 计算费用和输出
        uint256 fee = (amountIn * 3) / 1000; // 0.3%
        uint256 amountInAfterFee = amountIn - fee;
        amountOut = getAmountOut(amountInAfterFee, reserveETH, reserveToken);
        require(amountOut >= minAmountOut, "Insufficient output amount");

        // 发送费用到 feeTo
        address feeTo = DexFactory(factory).feeTo();
        (bool successFee, ) = feeTo.call{value: fee}("");
        require(successFee, "Fee transfer failed");

        // 更新储备
        reserveETH += amountInAfterFee;
        reserveToken -= amountOut;

        require(IERC20(token).transfer(to, amountOut), "Token transfer failed");
        emit Swap(msg.sender, amountIn, 0, 0, amountOut);
        return amountOut;
    }

    // Swap: Token -> ETH
    function swapTokenToETH(uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid token amount");
        require(reserveETH > minAmountOut, "Insufficient liquidity");

        // 支持 Fee-on-Transfer
        // 计算费用和输出
        uint256 fee = (amountIn * 3) / 1000; // 0.3%
        uint256 amountInAfterFee = amountIn - fee;
        amountOut = getAmountOut(amountIn, reserveToken, reserveETH);
        console.log(amountOut);
        require(amountOut >= minAmountOut, "Insufficient output amount");

        // 发送费用到 feeTo
        address feeTo = DexFactory(factory).feeTo();
        require(IERC20(token).transfer(feeTo, fee), "Fee transfer failed");

        // 更新储备
        reserveToken += amountInAfterFee;
        reserveETH -= amountOut;

        (bool success, ) = to.call{value: amountOut}("");
        require(success, "ETH transfer failed");
        emit Swap(msg.sender, 0, amountIn, amountOut, 0);
        return amountOut;
    }

    // 辅助函数
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    receive() external payable {}
}