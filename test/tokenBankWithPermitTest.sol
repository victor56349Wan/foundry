// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/tokenBankWithPermitDeposit.sol";
import "../src/erc20Permit.sol";
import "../src/erc20WithFee.sol";
contract TokenBankPermitDepositTest is Test {
    ERC20Permit _token;
    ERC20Permit _token2;
    TokenBankPermitDeposit _bank;
    address _owner;
    address _spender;
    uint256 _ownerPrivateKey;
    ERC20WithFee _tokenWithFee;

    function setUp() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        _ownerPrivateKey = alicePk;
        _owner = alice;
        _spender = address(0x456);
        address[] memory initialTokens = new address[](2);
        _token = new ERC20Permit("TestToken1", "TTK1", 18, 1000 ether);
        _token2 = new ERC20Permit("TestToken2", "TTK2", 18, 1000 ether);    // not used in token bank
        initialTokens[0] = address(_token);
        vm.deal(_owner, 1 ether);
        _token.transfer(_owner, 500 ether);
        _token2.transfer(_owner, 500 ether);

        _tokenWithFee = new ERC20WithFee("TestTokenWithFee", "TTKFee", 18, 1000 ether, 10);
        _tokenWithFee.transfer(_owner, 500 ether);

        
        initialTokens[1] = address(_tokenWithFee);

        _bank = new TokenBankPermitDeposit(initialTokens);

    }

    function testBankPermitDeposit() public {
        uint256 nonce = _token.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                _token.PERMIT_TYPEHASH(),
                _owner,
                address(_bank),
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encode(
                "\x19\x01",
                _token.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_ownerPrivateKey, digest);

        vm.prank(_owner);
        PermitStruct memory permitData = PermitStruct(_owner, address(_bank), value, nonce, deadline);
        _bank.permitDeposit(address(_token), permitData, v, r, s);

        assertEq(_token.balanceOf(address(_bank)), value);
        assertEq(_token.nonces(_owner), nonce + 1);
    }

    function testBankPermitDepositAmountZero() public {
        uint256 nonce = _token.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 0;

        bytes32 structHash = keccak256(
            abi.encode(
                _token.PERMIT_TYPEHASH(),
                _owner,
                address(_bank),
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encode(
                "\x19\x01",
                _token.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_ownerPrivateKey, digest);

        vm.prank(_owner);
        PermitStruct memory permitData = PermitStruct(_owner, address(_bank), value, nonce, deadline);
        vm.expectRevert("Amount must be greater than 0");
        _bank.permitDeposit(address(_token), permitData, v, r, s);
    }

    function testBankPermitDepositTokenNotSupported() public {
        uint256 nonce = _token2.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                _token2.PERMIT_TYPEHASH(),
                _owner,
                address(_bank),
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encode(
                "\x19\x01",
                _token2.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_ownerPrivateKey, digest);

        vm.prank(_owner);
        PermitStruct memory permitData = PermitStruct(_owner, address(_bank), value, nonce, deadline);
        vm.expectRevert("Token not supported");
        _bank.permitDeposit(address(_token2), permitData, v, r, s); // 使用不支持的 token 地址
    }

    function testBankPermitDepositSpenderNotContract() public {
        uint256 nonce = _token.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                _token.PERMIT_TYPEHASH(),
                _owner,
                _token2, // 使用不正确的 spender 地址
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encode(
                "\x19\x01",
                _token.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_ownerPrivateKey, digest);

        vm.prank(_owner);
        PermitStruct memory permitData = PermitStruct(_owner, address(_token2), value, nonce, deadline);
        vm.expectRevert("spender must be this contract");
        _bank.permitDeposit(address(_token), permitData, v, r, s);
    }

    function testBankPermitDepositBalanceNotAddUp() public {
        uint256 nonce = _tokenWithFee.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                _tokenWithFee.PERMIT_TYPEHASH(),
                _owner,
                address(_bank),
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encode(
                "\x19\x01",
                _tokenWithFee.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_ownerPrivateKey, digest);
        /* 需要在被测试的合约里添加 mockCall 函数
        // 模拟 safeTransferFrom 调用后 owner 的 token 余额发生变化
        vm.mockCall(
            address(_tokenWithFee),
            abi.encodeWithSelector(IERC20.transferFrom.selector, _owner, address(_bank), value),
            abi.encode(true)
        );
        vm.mockCall(
            address(_tokenWithFee),
            abi.encodeWithSelector(IERC20.balanceOf.selector, _owner),
            abi.encode(400 ether) // 模拟余额变化
        );

        */

        vm.prank(_owner);
        PermitStruct memory permitData = PermitStruct(_owner, address(_bank), value, nonce, deadline);
        vm.expectRevert("Balance NOT add up");
        _bank.permitDeposit(address(_tokenWithFee), permitData, v, r, s);
    }

    function testThirdPartyBankPermitDeposit() public {
        address thirdParty = makeAddr("thirdParty");
        
        uint256 nonce = _token.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                _token.PERMIT_TYPEHASH(),
                _owner,
                address(_bank),
                value,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encode(
                "\x19\x01",
                _token.DOMAIN_SEPARATOR(),
                structHash
            )
        );

        // 签名者(_owner)签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_ownerPrivateKey, digest);

        // 记录交易前的余额
        uint256 bankBalanceBefore = _token.balanceOf(address(_bank));
        uint256 ownerBalanceBefore = _token.balanceOf(_owner);

        // 第三方提交交易
        vm.prank(thirdParty);
        PermitStruct memory permitData = PermitStruct(_owner, address(_bank), value, nonce, deadline);
        _bank.permitDeposit(address(_token), permitData, v, r, s);

        // 验证存款是否成功
        assertEq(_token.balanceOf(address(_bank)), bankBalanceBefore + value);
        assertEq(_token.balanceOf(_owner), ownerBalanceBefore - value);
        assertEq(_bank.balances(_owner, address(_token)), value);
        assertEq(_token.nonces(_owner), nonce + 1);
    }
}