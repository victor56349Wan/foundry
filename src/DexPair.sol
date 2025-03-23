// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DexPair {
    address public token; // USDT 地址
    uint256 public reserveETH; // ETH 储备量
    uint256 public reserveToken; // USDT 储备量
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    bool private initialized;

    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, bool isETHIn);

    function initialize(address _token) external {
        require(!initialized, "Already initialized");
        token = _token;
        initialized = true;
    }

    // 获取储备
    function getReserves() public view returns (uint256 _reserveETH, uint256 _reserveToken) {
        return (reserveETH, reserveToken);
    }

    // 添加初始流动性（简化版，仅限测试）
    function addLiquidity() external payable {
        require(msg.value > 0, "Must send ETH");
        uint256 tokenAmount = IERC20(token).balanceOf(address(this)) - reserveToken;
        require(tokenAmount > 0, "Must send token");

        if (reserveETH == 0 && reserveToken == 0) {
            reserveETH = msg.value;
            reserveToken = tokenAmount;
        } else {
            uint256 ethAmount = msg.value;
            uint256 expectedToken = (ethAmount * reserveToken) / reserveETH;
            require(tokenAmount >= expectedToken, "Insufficient token amount");
            reserveETH += ethAmount;
            reserveToken += tokenAmount;
        }
    }

    // Swap 计算输出量（含 0.3% 手续费）
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        uint256 amountInWithFee = amountIn * 997; // 0.3% 费用
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    // ETH -> Token
    function swapETHForToken(uint256 minAmountOut, address to) external payable {
        require(msg.value > 0, "Must send ETH");
        (uint256 _reserveETH, uint256 _reserveToken) = getReserves();
        uint256 amountOut = getAmountOut(msg.value, _reserveETH, _reserveToken);

        require(amountOut >= minAmountOut, "Insufficient output amount");
        reserveETH += msg.value;
        reserveToken -= amountOut;

        require(IERC20(token).transfer(to, amountOut), "Transfer failed");
        emit Swap(msg.sender, msg.value, amountOut, true);
    }

    // Token -> ETH
    function swapTokenForETH(uint256 amountIn, uint256 minAmountOut, address to) external {
        require(amountIn > 0, "Invalid input amount");
        (uint256 _reserveETH, uint256 _reserveToken) = getReserves();
        uint256 amountOut = getAmountOut(amountIn, _reserveToken, _reserveETH);

        require(amountOut >= minAmountOut, "Insufficient output amount");
        uint256 tokenBalanceBefore = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        uint256 actualAmountIn = IERC20(token).balanceOf(address(this)) - tokenBalanceBefore; // 支持 Fee-on-Transfer

        reserveToken += actualAmountIn;
        reserveETH -= amountOut;

        (bool success, ) = to.call{value: amountOut}("");
        require(success, "ETH transfer failed");
        emit Swap(msg.sender, actualAmountIn, amountOut, false);
    }

    receive() external payable {}
}