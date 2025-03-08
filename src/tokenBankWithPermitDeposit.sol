// SPDX-License-Identifier: MIT
/*
1. 使用 EIP2612 标准（可基于 Openzepplin 库）编写一个自己名称的 Token 合约。
2. 修改 TokenBank 存款合约 ,添加一个函数 permitDeposit 以支持离线签名授权（permit）进行存款。

要求: 
1, 有 Token 存款及 NFT 购买成功的测试用例
2, 有测试用例运行日志或截图，能够看到 Token 及 NFT 转移。

*/

pragma solidity >= 0.8.0;


import "./tokenBank.sol";
import "./IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract TokenBankPermitDeposit is TokenBank{
    using SafeERC20 for IERC20;
    constructor(address[] memory _initialTokens) TokenBank(_initialTokens) {

    }

    function permitDeposit(address token, PermitStruct calldata permitData, uint8 v, bytes32 r, bytes32 s) external{
        // call permit of erc20WithPermit
        IERC20Permit(token).permit(permitData, v, r, s);
        uint256 amount = permitData.value;
        require(amount > 0, "Amount must be greater than 0");

        // Optional: Check if token is supported (remove this if all ERC-20s are allowed)
        require(supportedTokens[token], "Token not supported");

        address spender = permitData.spender;
        require(spender == address(this), "spender must be this contract");

        // record the balance of the bank
        address owner = permitData.owner;
        uint256 balance = IERC20(token).balanceOf(spender);

        // Transfer the token from the owner to the spender
        //IERC20(token).safeTransferFrom(owner, spender, amount);
        IERC20(token).safeTransferFrom(owner, spender, amount);

        // Check if the balance in bank has been updated correctly
        require(balance + amount == IERC20(token).balanceOf(spender), 'Balance NOT add up');

        // Update the balance in the bank
        balances[owner][token] += amount;

        emit Deposited(owner, token, amount);        
    }
}