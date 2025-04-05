// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/CallOptionToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 简单DEX合约
contract SimpleDEX {
    using SafeERC20 for IERC20;
    
    struct Pool {
        uint256 tokenAReserve;
        uint256 tokenBReserve;
        uint256 price;  // tokenB/tokenA 价格
    }
    
    mapping(address => mapping(address => Pool)) public pools;
    
    // 创建交易对
    function createPool(address tokenA, address tokenB, uint256 price) external {
        require(pools[tokenA][tokenB].price == 0, "Pool exists");
        pools[tokenA][tokenB].price = price;
        console.log("Pool price: ", pools[tokenA][tokenB].price);
    }
    
    // 添加流动性
    function addLiquidity(address tokenA, address tokenB, uint256 amountA) external {
        Pool storage pool = pools[tokenA][tokenB];
        console.log("Pool price: ", pool.price);
        require(pool.price > 0, "Pool not exists");
        
        // 修改: 计算期权Token数量，price是每个期权Token的价格
        uint256 amountB = (amountA * 1e18) / pool.price;
        console.log("Add liquidity amountA: ", amountA, " amountB: ", amountB);
        
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        pool.tokenAReserve += amountA;
        pool.tokenBReserve += amountB;
    }
    
    // 交易
    function swap(address tokenA, address tokenB, uint256 amountA) external returns (uint256) {
        Pool storage pool = pools[tokenA][tokenB];
        require(pool.price > 0, "Pool not exists");
        
        // 修改: 计算可获得的期权Token数量
        uint256 amountB = (amountA * 1e18) / pool.price;
        console.log("Swap amountA: ", amountA, " amountB: ", amountB);
        console.log("Pool tokenAReserve: ", pool.tokenAReserve, " Pool tokenBReserve: ", pool.tokenBReserve);
        require(pool.tokenBReserve >= amountB, "Insufficient liquidity");
        
        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);
        
        pool.tokenAReserve += amountA;
        pool.tokenBReserve -= amountB;
        
        return amountB;
    }
}

// 模拟支付代币
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract CallOptionTokenTest is Test {
    CallOptionToken public optionToken;
    MockERC20 public paymentToken;
    SimpleDEX public dex;
    address public user = address(1);
    uint256 public constant STRIKE_PRICE = 2000 * 10**18; // 行权价格2000U
    uint256 public constant OPTION_PRICE = 100 * 10**18;  // 期权价格100U
    uint256 public totalMintedEth;  // 新增：跟踪铸造使用的总ETH
    
    function setUp() public {
        // 部署模拟支付代币
        paymentToken = new MockERC20();
        dex = new SimpleDEX();
        

        // 部署期权Token合约
        optionToken = new CallOptionToken(
            "ETH Call Option",
            "ETHC",
            STRIKE_PRICE,
            7, // 7天后到期
            address(paymentToken)
        );
        
        // 给测试用户转一些支付代币
        paymentToken.transfer(user, 10000 * 10**18);
        
        // 给合约转一些ETH用于铸造期权
        vm.deal(address(this), 100 ether);
        
        // 记录铸造使用的ETH数量
        totalMintedEth = 10 ether;
        optionToken.mint{value: totalMintedEth}();
        
        // 创建交易对 (注意：tokenA是支付代币，tokenB是期权Token)
        dex.createPool(address(paymentToken), address(optionToken), OPTION_PRICE);
        
        // 添加流动性前再铸造更多期权Token
        // 记录第二次铸造的ETH数量
        totalMintedEth += 90 ether;
        optionToken.mint{value: 90 ether}();
        
        // 修改：增加添加的流动性数量
        optionToken.approve(address(dex), type(uint256).max);
        paymentToken.approve(address(dex), type(uint256).max);
        dex.addLiquidity(address(paymentToken), address(optionToken), 10000 * 10**18);

    }
    
    // 通过DEX购买期权并行权的测试
    function testExerciseOption() public {
        vm.startPrank(user);
        
        // 打印初始余额
        console.log("Initial user ETH balance: ", user.balance);
        console.log("Initial user payment token balance: ", paymentToken.balanceOf(user));
        
        // 用户授权DEX使用支付代币
        paymentToken.approve(address(dex), type(uint256).max);
        
        // 通过DEX购买期权Token (注意：顺序要和createPool一致)
        uint256 amountIn = 100 * 10**18; // 支付100 token
        dex.swap(address(paymentToken), address(optionToken), amountIn);
        
        // 授权支付代币用于行权
        paymentToken.approve(address(optionToken), type(uint256).max);
        
        // 打印行权前余额
        console.log("Pre-exercise option token balance: ", optionToken.balanceOf(user));
        console.log("Pre-exercise ETH balance: ", user.balance);
        
        uint256 balanceBefore = user.balance;
        optionToken.exercise(1 ether);
        
        // 验证ETH增加了正确的数量
        assertEq(user.balance - balanceBefore, 1 ether);
        
        // 打印行权后余额
        console.log("Post-exercise ETH balance: ", user.balance);
        
        // 验证ETH已收到
        assertEq(user.balance, 1 ether);
        
        // 验证支付代币已扣除(DEX购买花费 + 行权价格)
        assertEq(
            paymentToken.balanceOf(user), 
            10000 * 10**18 - amountIn - STRIKE_PRICE
        );
        
        vm.stopPrank();
    }
    
    function testTradeOption() public {
        vm.startPrank(user);
        
        // 用户授权DEX使用支付代币
        paymentToken.approve(address(dex), type(uint256).max);
        
        // 用户用payment token购买期权 (注意：顺序要和createPool一致)
        uint256 amountIn = 100 * 10**18;
        dex.swap(address(paymentToken), address(optionToken), amountIn);
        
        // 验证用户获得了期权Token
        assertEq(optionToken.balanceOf(user), 1 ether);
        
        vm.stopPrank();
    }
    
    // 测试行权时间过期
    function testExerciseExpired() public {
        vm.startPrank(user);
        
        // 购买期权Token
        paymentToken.approve(address(dex), type(uint256).max);
        dex.swap(address(paymentToken), address(optionToken), 100 * 10**18);
        
        // 时间快进8天 (超过7天的到期时间)
        vm.warp(block.timestamp + 8 days);
        
        // 授权支付代币
        paymentToken.approve(address(optionToken), type(uint256).max);
        
        // 尝试行权，应该失败
        vm.expectRevert("Option expired");
        optionToken.exercise(1 ether);
        
        vm.stopPrank();
    }
    
    // 测试期权Token余额不足
    function testExerciseInsufficientOption() public {
        vm.startPrank(user);
        
        // 购买少量期权Token
        paymentToken.approve(address(dex), type(uint256).max);
        dex.swap(address(paymentToken), address(optionToken), 50 * 10**18); // 只买0.5个期权
        
        // 尝试行权更多数量
        paymentToken.approve(address(optionToken), type(uint256).max);
        vm.expectRevert("Insufficient option tokens");
        optionToken.exercise(1 ether);
        
        vm.stopPrank();
    }
    
    // 测试支付Token余额不足
    function testExerciseInsufficientPaymentToken() public {
        vm.startPrank(user);
        
        // 购买期权Token
        paymentToken.approve(address(dex), type(uint256).max);
        dex.swap(address(paymentToken), address(optionToken), 100 * 10**18);
        
        // 转走大部分支付代币，使余额不足以支付行权价格
        paymentToken.transfer(address(1234), 9000 * 10**18);
        
        // 尝试行权
        paymentToken.approve(address(optionToken), type(uint256).max);
        vm.expectRevert("Insufficient token balance");
        optionToken.exercise(1 ether);
        
        vm.stopPrank();
    }
    
    // 测试正常过期销毁
    function testExpire1() public {
        // 记录初始状态
        uint256 beforeBalance = address(this).balance;
        
        // 从DEX获取期权Token的余额
        uint256 dexBalance = optionToken.balanceOf(address(dex));
        console.log("DEX option balance: ", dexBalance);
        
        // 从DEX中转出期权Token
        vm.startPrank(address(dex));
        optionToken.transfer(address(optionToken), dexBalance);
        vm.stopPrank();
        
        // 快进到过期时间
        vm.warp(block.timestamp + 8 days);
        
        // 打印销毁前的状态
        console.log("Contract option balance: ", optionToken.balanceOf(address(optionToken)));
        console.log("Total supply: ", optionToken.totalSupply());
        console.log("Total minted ETH: ", totalMintedEth);
        
        // 执行过期销毁
        optionToken.expire();
        
        // 打印销毁后的状态
        console.log("Post total supply: ", optionToken.totalSupply());
        console.log("ETH balance change: ", address(this).balance - beforeBalance);
        
        // 验证所有Token被销毁
        assertEq(optionToken.totalSupply(), 0);
        
        // 验证返还的ETH数量与铸造时使用的一致
        assertEq(address(this).balance - beforeBalance, totalMintedEth);
    }
    
    // 测试未到期时尝试销毁
    function testExpireBeforeExpiry() public {
        vm.expectRevert("Not expired yet");
        optionToken.expire();
    }
    
    // 测试非所有者尝试销毁
    function testExpireNotOwner() public {
        vm.startPrank(user);
        vm.warp(block.timestamp + 8 days);
        
        // 修改: 使用完整的错误消息格式
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        optionToken.expire();
        
        vm.stopPrank();
    }

    receive() external payable {}
}
