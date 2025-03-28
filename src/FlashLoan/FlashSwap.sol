// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
任务: 编写合约执行闪电兑换,
步骤: 
1, 在测试网上部署两个自己的 ERC20 token合约( a和b) ，
2, 再部署两个 UniswapV2交易所合约A和B，
3, 在两个Dex 上各创建一个Uniswap V2 token a-b交易对的流动池（称为 PoolA 和 PoolB），让PoolA 和 PoolB 形成价差，创造套利条件
4, 在 闪电贷合约实现里, 在UniswapV2Call中，用从PoolA 收到的 Token a 在PoolB 兑换为 Token b 并还回到 uniswapV2 Pair 中。
 */
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DexPair.sol";
import "./DexFactory.sol";


contract FlashSwap is IUniswapV2Callee {
    address public dexAFactory;
    address public dexBFactory;

    constructor(address _dexAFactory, address _dexBFactory) {
        dexAFactory = _dexAFactory;
        dexBFactory = _dexBFactory;
    }

    // 启动闪电兑换
    function executeFlashSwap(address tokenA, address tokenB, uint256 amountA) external {
        address pairA = DexFactory(dexAFactory).getPair(tokenA, tokenB);
        require(pairA != address(0), "PairA does not exist");
        address token0 = DexPair(pairA).token0();
        address token1 = DexPair(pairA).token1();
        // 从 PoolA 借 TokenA
        if ( DexPair(pairA).token0() == tokenA )
            DexPair(pairA).swap(amountA, 0, address(this), abi.encode(tokenA, tokenB));
        else if ( DexPair(pairA).token1() == tokenA )
            DexPair(pairA).swap(0, amountA, address(this), abi.encode(tokenA, tokenB));
        else
            revert("Invalid token");
        // 处理利润
        uint256 profit = IERC20(tokenB).balanceOf(address(this));
        if (profit > 0) {
            IERC20(tokenB).transfer(msg.sender, profit);
        }

    }

    // Uniswap V2 回调函数
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        (address tokenA, address tokenB) = abi.decode(data, (address, address));
        address pairA = DexFactory(dexAFactory).getPair(tokenA, tokenB);
        require(msg.sender == pairA, "Invalid caller");
        require(amount0 > 0 || amount1 > 0, "Must borrow something");

        uint256 amountReceived = amount0 > 0 ? amount0 : amount1; // TokenA 数量 TODO: 
        address pairB = DexFactory(dexBFactory).getPair(tokenA, tokenB);
        
        // 在 PoolB 中兑换
        {
            // IERC20(tokenA).approve(pairB, amountReceived);
            IERC20(tokenA).transfer(pairB, amountReceived);
            (uint256 reserve0, uint256 reserve1) = DexPair(pairB).getReserves();
            address token0 = DexPair(pairB).token0();
            address token1 = DexPair(pairB).token1();
            uint256 amountBOut = getAmountOut(
                amountReceived, 
                token0 == tokenA ? reserve0 : reserve1,
                token0 == tokenB ? reserve0 : reserve1
            );
            DexPair(pairB).swap(
                token0 == tokenB ? amountBOut : 0,
                token1 == tokenB ? amountBOut : 0,
                address(this),
                bytes("")
            );
        }

        // 计算还款金额并还款
        {
            (uint256 reserve0, uint256 reserve1) = DexPair(pairA).getReserves();
            address token0 = DexPair(pairA).token0();
            address token1 = DexPair(pairA).token1();
            uint256 amountToRepay = getAmountIn(
                amountReceived,
                token0 == tokenB ? reserve0 : reserve1,
                token0 == tokenA ? reserve0 : reserve1
            );
            IERC20(tokenB).transfer(pairA, amountToRepay);
        }

        // 处理利润
        uint256 profit = IERC20(tokenB).balanceOf(address(this));
        require(profit > 0, "No profit");
        /**
        if (profit > 0) {
            IERC20(tokenB).transfer(sender, profit);
        }
         */
    }

    // 计算输出量
    function getAmountOutOrig(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997 / 1000;
        return (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
    }
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997 / 1000;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut;
        uint denominator = reserveOut - amountOut;
        amountIn = (numerator / denominator)*1000/997 + 1;
    }


}