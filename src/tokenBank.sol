// SPDX-License-Identifier: MIT
/*编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。

TokenBank 有两个方法：

deposit() : 需要记录每个地址的存入数量；
withdraw（）: 用户可以提取自己的之前存入的 token。
*/

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "./base_erc20.sol";

contract TokenBank {

    // Mapping to track the deposit balance for each address
    mapping(address => uint) public balances;
    IERC20 public erc20Token;

    constructor (address _erc20Token) {
        erc20Token = IERC20(_erc20Token);
    }

    //deposit() : 需要记录每个地址的存入数量；
    function deposit(uint amount) public {
        IERC20(erc20Token).transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }
    function withdraw(uint amount) external {

        require(balances[msg.sender] >= amount, 'Insufficient token');
        balances[msg.sender] -= amount;
        IERC20(erc20Token).transfer(msg.sender, amount);
    }
    function withdrawAll() external {
        uint amount = balances[msg.sender];
        require(amount > 0, 'Insufficient token');
        balances[msg.sender] = 0;
        IERC20(erc20Token).transfer(msg.sender, amount);
    }    
}