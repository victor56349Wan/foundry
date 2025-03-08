// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/erc20Permit.sol";

contract ERC20PermitTest is Test {
    ERC20Permit _token;
    address _owner;
    address _spender;
    uint256 _ownerPrivateKey;

    function setUp() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        _ownerPrivateKey = alicePk;
        _owner = alice;
        _spender = address(0x456);
        _token = new ERC20Permit("TestToken", "TTK", 18, 1000 ether);
        vm.deal(_owner, 1 ether);
    }

    function testPermit() public {
        uint256 nonce = _token.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                _token.PERMIT_TYPEHASH(),
                _owner,
                _spender,
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
        PermitStruct memory structData = PermitStruct(_owner, _spender, value, nonce, deadline);
        console.log("before permit: _owner", _owner);
        console.log("_spender", _spender);
        console.log("value", value);
        console.log("nonce", nonce);
        console.log("deadline", deadline);
        _token.permit(structData, v, r, s);

        assertEq(_token.allowance(_owner, _spender), value);
        assertEq(_token.nonces(_owner), nonce + 1);
    }

    function testPermitExpired() public {
        uint256 nonce = _token.nonces(_owner);
        uint256 deadline = block.timestamp + 1 days; // 设置过期时间
        uint256 value = 100 ether;  

        bytes32 structHash = keccak256(
            abi.encode(
                _token.PERMIT_TYPEHASH(),
                _owner,
                _spender,
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
        
        // 模拟时间过期
        vm.warp(block.timestamp + 1 days + 1 seconds);

        vm.prank(_owner);
        PermitStruct memory structData = PermitStruct(_owner, _spender, value, nonce, deadline);
        vm.expectRevert("expired deadline");
        _token.permit(structData, v, r, s);
    }

    function testPermitNonceMismatch() public {
        uint256 nonce = _token.nonces(_owner) + 1; // 设置不匹配的 nonce
        uint256 deadline = block.timestamp + 1 days;
        uint256 value = 100 ether;

        bytes32 structHash = keccak256(
            abi.encode(
                _token.PERMIT_TYPEHASH(),
                _owner,
                _spender,
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
        PermitStruct memory structData = PermitStruct(_owner, _spender, value, nonce, deadline);
        vm.expectRevert("mismatched nonce");
        _token.permit(structData, v, r, s);
    }

    function testPermitFuzzy() public {
        for (uint256 i = 0; i < 10; i++) {
            uint256 nonce = _token.nonces(_owner) + i; // 模糊测试 nonce
            uint256 deadline = block.timestamp + 1 days; // 模糊测试过期时间
            uint256 value = 100 ether;

            bytes32 structHash = keccak256(
                abi.encode(
                    _token.PERMIT_TYPEHASH(),
                    _owner,
                    _spender,
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

            // 模拟时间过期
            // 模拟时间过期
            uint256 timeOffset = 1 days;
            if (i % 2 == 0) {
                timeOffset = timeOffset + i * 1 seconds;
            } else {
                timeOffset = timeOffset - i * 1 seconds;
            }            
            vm.warp(block.timestamp + timeOffset);

            vm.prank(_owner);
            PermitStruct memory structData = PermitStruct(_owner, _spender, value, nonce, deadline);

            if (deadline < block.timestamp) {
                vm.expectRevert("expired deadline");
            } else if (nonce != _token.nonces(_owner)) {
                vm.expectRevert("mismatched nonce");
            }

            _token.permit(structData, v, r, s);
        }
    }
}