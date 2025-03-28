// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

contract DexPair {
    address public factory;
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;

    uint256 constant MINIMUM_LIQUIDITY = 10**3;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(address indexed sender, uint256 amount0Out, uint256 amount1Out, address indexed to);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "Only factory");
        require(token0 == address(0) && token1 == address(0), "Already initialized");
        token0 = _token0;
        token1 = _token1;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {
        address _token0 = tokenA == token0? tokenA: (tokenB == token0? tokenB: address(0));
        address _token1 = tokenA == token1? tokenA: (tokenB == token1? tokenB: address(0));
        require( tokenA == token0 && tokenB == token1 
            || tokenA == token1 && tokenB == token0, "Invalid tokens");
        uint256 amount0 = token0 == tokenA ? amountA: amountB;
        uint256 amount1 = token1 == tokenA ? amountA: amountB;

        require(IERC20(token0).transferFrom(msg.sender, address(this), amount0), "Transfer failed");
        require(IERC20(token1).transferFrom(msg.sender, address(this), amount1), "Transfer failed");
        if (reserve0 == 0 && reserve1 == 0) {
            reserve0 = amount0 - MINIMUM_LIQUIDITY;
            reserve1 = amount1 - MINIMUM_LIQUIDITY;
        } else {
            reserve0 += amount0;
            reserve1 += amount1;
        }
        emit Mint(msg.sender, amount0, amount1);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        require(amount0Out > 0 || amount1Out > 0, "Insufficient output");
        (uint256 _reserve0, uint256 _reserve1) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "Insufficient liquidity");

        if (amount0Out > 0) IERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) IERC20(token1).transfer(to, amount1Out);

        if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);

        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "Insufficient input");

        // 含 0.3% 费用的恒定乘积检查
        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        require(balance0Adjusted * balance1Adjusted >= _reserve0 * _reserve1 * 1000 * 1000, "K invariant failed");

        reserve0 = balance0;
        reserve1 = balance1;
        emit Swap(msg.sender, amount0Out, amount1Out, to);
    }
}