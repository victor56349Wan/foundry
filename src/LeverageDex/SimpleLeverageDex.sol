pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/Test.sol";

// 极简的杠杆 DEX 实现， 完成 TODO 代码部分
contract SimpleLeverageDEX {

    uint public vK;  // 100000 
    uint public vETHAmount;
    uint public vUSDCAmount;

    IERC20 public USDC;  // 自己创建一个币来模拟 USDC

    struct PositionInfo {
        uint256 margin; // 保证金    // 真实的资金， 如 USDC 
        uint256 borrowed; // 借入的资金
        int256 position;    // 虚拟 eth 持仓
    }
    mapping(address => PositionInfo) public positions;

    constructor(uint vEth, uint vUSDC , address usdcAddress) {
        USDC = IERC20(usdcAddress);
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;

    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint level, bool long) external {
        require(positions[msg.sender].position == 0, "Position already open");

        PositionInfo storage pos = positions[msg.sender] ;

        USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
        uint amount = _margin * level;
        uint256 borrowAmount = amount - _margin;
        require(amount < vUSDCAmount, "Insufficient liquidity"); // 检查借入的资金是否足够
        pos.margin = _margin;
        pos.borrowed = borrowAmount;
        uint256 deltaUSDCWithFee = amount * 997 / 1000; // 99.7% 的资金可以用来开仓
        // TODO:
        if (long) {
            pos.position = int256(getAmountOut(deltaUSDCWithFee, vUSDCAmount, vETHAmount)); // 计算开仓的 eth 数量
            vETHAmount -= uint256(pos.position); // 更新 vETHAmount
            vUSDCAmount += deltaUSDCWithFee; // 更新 vUSDCAmount
        } else {
            pos.position = -int256(getAmountIn(deltaUSDCWithFee, vETHAmount, vUSDCAmount)); // 计算开仓的 eth 数量
            vETHAmount += uint256(-pos.position); // 更新 vETHAmount
            vUSDCAmount -= deltaUSDCWithFee; // 更新 vUSDCAmount
        }
        
        require(vETHAmount * vUSDCAmount >= vK, "Insufficient liquidity"); // 检查流动性 
    }

    // 关闭头寸并结算, 不考虑协议亏损
    function closePosition() external {
        // TODO:
        require(positions[msg.sender].position != 0, "No position");
        PositionInfo storage pos = positions[msg.sender];
        int256 vETHPosition = pos.position;
        uint256 currentPositionValue;
        uint256 amountUSDCOfUser;
        if (vETHPosition > 0) {
            // 平多仓
            currentPositionValue = getAmountOut(uint256(vETHPosition), vETHAmount, vUSDCAmount);
            amountUSDCOfUser = currentPositionValue - pos.borrowed; // 用户的利润
            USDC.transfer(msg.sender, amountUSDCOfUser);
            vETHAmount += uint256(vETHPosition); // 更新 vETHAmount
            vUSDCAmount -= currentPositionValue; // 更新 vUSDCAmount
        } else {
            // 平空仓
            currentPositionValue = getAmountIn(uint256(-vETHPosition), vUSDCAmount, vETHAmount);
            amountUSDCOfUser = currentPositionValue - pos.borrowed; // 用户的利润
            USDC.transfer(msg.sender, amountUSDCOfUser);
            vETHAmount -= uint256(-vETHPosition); // 更新 vETHAmount
            vUSDCAmount += currentPositionValue; // 更新 vUSDCAmount
        }

        require(vETHAmount * vUSDCAmount >= vK, "Insufficient   liquidity"); // 检查流动性

        delete positions[msg.sender]; // 删除头寸
    }

    // 清算头寸， 清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意： 清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        PositionInfo memory pos = positions[_user];
        int256 vETHPosition = pos.position;
        require(vETHPosition != 0, "No position");
        require(msg.sender != _user, "Cannot liquidate self");
        int256 PnL = calculatePnL(_user);

        // TODO:
        require(PnL + int256(pos.margin * 8 / 10) < 0, "Not enough loss to liquidate");
        int256 netValue = PnL +  int256(pos.margin); 
        require(netValue > 0, "Not enough profit to liquidate"); // 资不抵债无法清算
        uint256 profitForLiquidator = uint256(netValue) * 997 / 1000; // 清算人获得的利润
        USDC.transfer(msg.sender, profitForLiquidator);
        require(vETHAmount * vUSDCAmount >= vK, "Insufficient liquidity"); // 检查流动性
        delete positions[_user];
        
    }

    // 计算盈亏： 对比当前的仓位和借的 vUSDC
    function calculatePnL(address user) public view returns (int256) {
        // TODO:
        require(positions[user].position != 0, "No position");
        // 计算当前的仓位和开仓价值
        int256 vETHPosition = positions[user].position;
        int256 PnL = 0;
        int256 currentPositionValue;
        if (vETHPosition > 0) {
            // 多单仓
            currentPositionValue = int256(getAmountOut(uint256(vETHPosition), vETHAmount, vUSDCAmount));
        } else {
            // 空单仓
            currentPositionValue = int256(getAmountIn(uint256(-vETHPosition), vUSDCAmount, vETHAmount));
        }
        PnL = currentPositionValue - int256(positions[user].borrowed) - int256(positions[user].margin);
        return PnL;

    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn ;
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
        amountIn = (numerator / denominator) + 1;
    }
}
