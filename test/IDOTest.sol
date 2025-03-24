// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/IDO/IDO.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**18);
    }
}

contract IDOTest is Test {
    IDO public ido;
    MockToken public token;
    address owner = makeAddr("owner");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        vm.startPrank(owner);
        ido = new IDO();
        token = new MockToken();
        vm.stopPrank();

        // 给测试用户转ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testStartSale() public {
        vm.startPrank(owner);
        uint256 tokenAmount = 100000 * 10**18;
        token.approve(address(ido), tokenAmount);
        
        ido.startSale(
            address(token),
            tokenAmount,
            0.001 ether,      // 价格: 0.001 ETH per token
            50 ether,         // 最低目标
            100 ether,        // 最高上限
            0.1 ether,        // 最低参与
            10 ether,         // 最高参与
            1 days           // 持续时间
        );
        vm.stopPrank();

        assertEq(token.balanceOf(address(ido)), tokenAmount);
    }

    function testContribute() public {
        // 先开启预售
        testStartSale();

        vm.prank(user1);
        ido.contribute{value: 1 ether}();

        assertEq(ido.contributions(user1), 1 ether);
        assertEq(ido.totalEthRaised(), 1 ether);
    }

    function testIDOFailBelowMinContribution() public {
        testStartSale();

        vm.prank(user1);
        vm.expectRevert("Below min contribution");
        ido.contribute{value: 0.05 ether}();
    }

    function testSuccessfulSale() public {
        testStartSale();
        
        // 从合约获取参数
        uint256 minEthTarget = ido.minEthTarget();
        uint256 maxPerUser = ido.maxEthPerUser();
        
        // 计算需要的最少用户数 (向上取整)
        uint256 requiredUsers = (minEthTarget + maxPerUser - 1) / maxPerUser;
        
        // 创建所需数量的用户
        address[] memory users = new address[](requiredUsers);
        for(uint i = 0; i < requiredUsers; i++) {
            users[i] = makeAddr(string.concat("user", vm.toString(i)));
            vm.deal(users[i], maxPerUser);
        }

        // 每个用户投入最大额度
        uint256 totalRaised = 0;
        for(uint i = 0; i < requiredUsers; i++) {
            vm.prank(users[i]);
            ido.contribute{value: maxPerUser}();
            totalRaised += maxPerUser;
        }

        // 结束预售
        vm.warp(block.timestamp + 1 days);
        ido.finalize();

        // 验证总募集金额超过最小目标
        assertEq(ido.totalEthRaised(), totalRaised);
        assertGe(totalRaised, minEthTarget);
        assertTrue(ido.isSuccessful());

        // 所有用户认领代币
        for(uint i = 0; i < requiredUsers; i++) {
            vm.prank(users[i]);
            ido.claim();
            // 每个用户应该获得 (maxPerUser / totalRaised) * totalIDOtokenAmount 的代币
            uint256 expectedTokens = (ido.totalIDOtokenAmount() * maxPerUser) / totalRaised;
            assertEq(token.balanceOf(users[i]), expectedTokens);
        }

        // 项目方提取ETH
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        ido.withdrawETH();
        assertEq(owner.balance - ownerBalanceBefore, totalRaised);
    }

    function testIDOFailToReachMinETHTarget() public {
        testStartSale();

        // 未达到最低目标
        vm.prank(user1);
        ido.contribute{value: 10 ether}();

        // 结束预售
        vm.warp(block.timestamp + 1 days);
        ido.finalize();

        // 用户请求退款
        uint256 user1BalanceBefore = user1.balance;
        vm.prank(user1);
        ido.claim();
        assertEq(user1.balance - user1BalanceBefore, 10 ether);
    }

    // 测试超过IDO时间后无法参与
    function testIDOFailAfterEndTime() public {
        testStartSale();
        
        // 时间前进超过预售结束时间
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(user1);
        vm.expectRevert("Sale ended");
        ido.contribute{value: 1 ether}();
    }

    // 测试单笔投资超过最大额度
    function testIDOFailExceedMaxContribution() public {
        testStartSale();
        
        uint256 maxPerUser = ido.maxEthPerUser();
        
        vm.prank(user1);
        vm.expectRevert("Exceeds max contribution");
        ido.contribute{value: maxPerUser + 1 ether}();
    }

    // 测试超过总募集上限
    function testIDOFailExceedMaxCap() public {
        testStartSale();
        
        uint256 maxCap = ido.maxEthCap();
        uint256 maxPerUser = ido.maxEthPerUser();
        
        // 计算需要多少用户才能达到接近上限
        uint256 requiredUsers = (maxCap + maxPerUser - 1 ) / maxPerUser;
        
        // 创建用户并让他们投资到接近上限
        for(uint i = 0; i < requiredUsers; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i)));
            vm.deal(user, maxPerUser);
            vm.prank(user);
            ido.contribute{value: maxPerUser}();
        }
        
        // 计算剩余可投资空间
        uint256 remainingCap = maxCap - ido.totalEthRaised();
        
        // 尝试投入超过剩余空间的ETH
        address userLast = makeAddr("userLast");
        vm.prank(userLast);
        vm.deal(userLast, maxPerUser * 2);
        vm.expectRevert("Exceeds max cap");
        ido.contribute{value: remainingCap + 1 ether}();
    }
}
