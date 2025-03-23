// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DexFactory.sol";
import "./DexPair.sol";

interface IDex {
    function sellETH(address buyToken, uint256 minBuyAmount) external payable;
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external;
}

contract MyDex is IDex {
    DexFactory public factory;
    uint256 public constant PRECISION = 1000; // 0.3% 费用因子

    constructor(address _factory) {
        factory = DexFactory(_factory);
    }

    // 卖出 ETH 兑换 USDT
    function sellETH(address buyToken, uint256 minBuyAmount) external payable override {
        require(msg.value > 0, "Must send ETH");
        address payable pair = factory.getPair(buyToken);
        require(pair != address(0), "Pair does not exist");

        // 创建 Pair 如果不存在（可选，视需求）
        if (pair == address(0)) {
            pair = factory.createPair(buyToken);
        }

        DexPair(pair).swapETHForToken{value: msg.value}(minBuyAmount, msg.sender);
    }

    // 用 USDT 买入 ETH
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external override {
        require(sellAmount > 0, "Invalid sell amount");
        address payable pair = factory.getPair(sellToken);
        require(pair != address(0), "Pair does not exist");

        DexPair(pair).swapTokenForETH(sellAmount, minBuyAmount, msg.sender);
    }

    // 获取预计输出量（辅助函数）
    function getAmountOut(address token, uint256 amountIn, bool isETHIn) external view returns (uint256 amountOut) {
        address payable pair = factory.getPair(token);
        if (pair == address(0)) return 0;

        (uint256 reserveETH, uint256 reserveToken) = DexPair(pair).getReserves();
        if (isETHIn) {
            return DexPair(pair).getAmountOut(amountIn, reserveETH, reserveToken);
        } else {
            return DexPair(pair).getAmountOut(amountIn, reserveToken, reserveETH);
        }
    }
}