// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DexFactory.sol";
import "./DexPair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDex {
    function sellETH(address buyToken, uint256 minBuyAmount) external payable;
    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external;
}

contract MyDex is IDex {
    DexFactory public factory;

    event ETHSold(address indexed user, address buyToken, uint256 ethAmount, uint256 tokenAmount);
    event ETHBought(address indexed user, address sellToken, uint256 tokenAmount, uint256 ethAmount);

    constructor(address _factory) {
        factory = DexFactory(_factory);
    }

    function sellETH(address buyToken, uint256 minBuyAmount) external payable override {
        require(msg.value > 0, "Must send ETH");
        address payable pair = factory.getPair(buyToken);
        require(pair != address(0), "Pair does not exist");

        // 如果 Pair 不存在，创建（可选）
        if (pair == address(0)) {
            pair = factory.createPair(buyToken);
        }

        uint256 amountOut = DexPair(pair).swapETHToToken{value: msg.value}(minBuyAmount, msg.sender);
        require(amountOut >= minBuyAmount, "Insufficient output amount");

        emit ETHSold(msg.sender, buyToken, msg.value, amountOut);
    }

    function buyETH(address sellToken, uint256 sellAmount, uint256 minBuyAmount) external override {
        require(sellAmount > 0, "Invalid sell amount");
        address payable pair = factory.getPair(sellToken);
        require(pair != address(0), "Pair does not exist");

        require(IERC20(sellToken).transferFrom(msg.sender, pair, sellAmount), "Token transfer failed");
        uint256 amountOut = DexPair(pair).swapTokenToETH(sellAmount, minBuyAmount, msg.sender);
        require(amountOut >= minBuyAmount, "Insufficient output amount");

        emit ETHBought(msg.sender, sellToken, sellAmount, amountOut);
    }
}