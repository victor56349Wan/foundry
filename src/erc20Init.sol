// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract ERC20Init is IERC20{
    string public name; 
    string public symbol; 
    uint8 public decimals; 
    uint256 public totalSupply; 

    mapping (address => uint256) balances; 

    mapping (address => mapping (address => uint256)) allowances; 

/**
    function initialize(string memory _name, 
        string memory _symbol, 
        uint8 _decimals, 
        uint _totalSupply) public{
        // write your code here
        // set name,symbol,decimals,totalSupply
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply*(10**decimals);
        //balances[msg.sender] = totalSupply; 
    }
 */
//允许任何人查看任何地址的 Token 余额（balanceOf）
    function balanceOf(address _owner) public view returns (uint256 balance) {
        // write your code here
        balance = balances[_owner];

    }
//允许 Token 的所有者将他们的 Token 发送给任何人（transfer）；
//转帐超出余额时抛出异常(require),并显示错误消息 “ERC20: transfer amount exceeds balance”。
    function transfer(address _to, uint256 _value) public virtual returns (bool success) {
        // write your code here
        /**
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        */
        _transfer(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, _value);  
        return true;   
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        balances[sender] -= amount;
        balances[recipient] += amount;        
    }

//允许被授权的地址消费他们被授权的 Token 数量（transferFrom）；
//转帐超出余额时抛出异常(require)，异常信息：“ERC20: transfer amount exceeds balance”
//转帐超出授权数量时抛出异常(require)，异常消息：“ERC20: transfer amount exceeds allowance”。    
    function transferFrom(address _from, address _to, uint256 _value) public virtual returns (bool success) {
        // write your code here
        require(allowances[msg.sender][_from] >= _value, "ERC20: transfer amount exceeds allowance");
        /**
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        balances[_from] -= _value;
        balances[_to] += _value;
        */ 
        _transfer(_from, _to, _value);
        allowances[msg.sender][_from] -= _value;
        emit Transfer(_from, _to, _value); 
        return true; 
    }

//允许 Token 的所有者批准某个地址消费他们的一部分Token（approve）

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        allowances[_spender][msg.sender] = _value;
        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function _approve(address _owner, address _spender, uint256 _value) internal {
        allowances[_spender][_owner] = _value;
    }
//允许任何人查看一个地址可以从其它账户中转账的代币数量（allowance）
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {   
        // write your code here    
        return allowances[_spender][_owner];

    }


    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: cannot mint to the zero address");

        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function mint(address to, uint256 amount) public virtual{
        _mint(to, amount);
    }    
}
