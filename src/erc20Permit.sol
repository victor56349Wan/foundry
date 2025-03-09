// SPDX-License-Identifier: MIT
pragma solidity ^0.8.00;
import "./base_erc20.sol";
import "./IERC20Permit.sol";
/**
要求：
使用 EIP2612 标准（可基于 Openzepplin 库）编写一个自己名称的 Token 合约。

要求: 
1, 有 Token 存款及 NFT 购买成功的测试用例
2, 有测试用例运行日志或截图，能够看到 Token 及 NFT 转移。

 */

contract ERC20Permit is BaseERC20, IERC20Permit{

    mapping(address => uint256) public nonce;
    function _useNonce(address owner) internal returns(uint256) {
        return nonce[owner]++;
    }
    function nonces(address owner) external view returns (uint256) {
        return nonce[owner];
    }

    bytes32 public immutable PERMIT_TYPEHASH = keccak256("permit(PermitStruct permit, bytes signature)PermitStruct(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public immutable DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public immutable DOMAIN_SEPARATOR;
    constructor(string memory name_, string memory symbol_, uint8 decimals_ , uint totalSupply_) BaseERC20(name_, symbol_, decimals_, totalSupply_){
        //DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name_)), keccak256(bytes('1')), block.chainid, address(this)));
        DOMAIN_SEPARATOR = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name_)), keccak256(bytes('31337')), block.chainid, address(this)));
    }

    function permit(PermitStruct calldata permitData, uint8 v, bytes32 r, bytes32 s) external{
        require(block.timestamp <= permitData.deadline, 'expired deadline');
        require(nonce[permitData.owner] == permitData.nonce, 'mismatched nonce');
        _useNonce(permitData.owner);
        
        // construct digest for verifying EIP712 signature
        // 1. hash for permit struct: type hash || encodeData
        bytes32 permitStructHash = keccak256(abi.encode(PERMIT_TYPEHASH, 
                                                        permitData.owner, 
                                                        permitData.spender, 
                                                        permitData.value,
                                                        permitData.nonce, 
                                                        permitData.deadline));

        // 2. generate digest for EIP712 signature
        bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, permitStructHash));
        
        // 3, recover signer using digest against v,r,s
        require(permitData.owner == ecrecover(digest, v, r, s), 'invalid signer');
        _approve(permitData.owner, permitData.spender, permitData.value);
    }

}