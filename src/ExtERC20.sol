// SPDX-License-Identifier: MIT
/*
题目#1
扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。

继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将 扩展的 ERC20 Token 存入到 TokenBankV2 中。

（备注：TokenBankV2 需要实现 tokensReceived 来实现存款记录工作）
*/

pragma solidity >= 0.8.0;

import "./base_erc20.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./tokenBank.sol";

interface ContractWithTokenReceiver{
    function tokensReceived(uint amount, bytes memory data) external returns(bool);
}





contract ExtERC20 is BaseERC20{
    address public owner;

     //constructor(string memory _name, string memory _symbol, uint8 _decimals, uint _totalSupply) {o
    constructor(string memory name_, string memory symbol_, uint8 decimals_ , uint totalSupply_) BaseERC20(name_, symbol_, decimals_, totalSupply_){
        owner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: cannot mint to the zero address");

        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
 
    
    function isContract(address addr) public view returns (bool) {
        uint256 size;
        // 直接调用汇编的 extcodesize 指令
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
    function transferWithCallback(address _to, uint amount, bytes memory data) external{
        require(super.transfer(_to, amount), "transfer failed");
        if (isContract(_to)) {
            bool success = ContractWithTokenReceiver(_to).tokensReceived(amount, data);
            require(success, "call tokensReceived failed");
        }
    } 

}

contract TokenBankV2 is TokenBank {
    constructor(address _extendedErc20Token) TokenBank(_extendedErc20Token){
    }

    function tokensReceived(uint amount, bytes memory data) external returns(bool){
        require(msg.sender == address(erc20Token), "Not my supported ERC20" );
        balances[tx.origin] += amount;
        return true;
    }
}