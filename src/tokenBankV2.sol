// SPDX-License-Identifier: MIT
/*
题目#1
扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。

继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。

（备注：TokenBankV2 需要实现 tokensReceived 来实现存款记录工作）
*/

pragma solidity >= 0.8.0;

import "./extERC20.sol";
import "./tokenBank.sol";

contract TokenBankV2 is TokenBank {
    constructor(address [] memory erc20Token) TokenBank(erc20Token){
    }

    function tokensReceived(uint amount, bytes memory data) external returns(bool){
        require(supportedTokens[msg.sender], "Token not supported");
        
        balances[tx.origin][msg.sender] += amount;
        return true;
    }


}
