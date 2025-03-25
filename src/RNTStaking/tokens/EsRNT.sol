// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RNT.sol";

contract EsRNT is ERC20, Ownable(msg.sender) {
    struct Lock {
        uint256 amount;
        uint256 startTime;
    }

    RNT public rnt;
    uint256 public constant LOCK_PERIOD = 30 days;
    mapping(address => Lock[]) public userLocks;

    constructor(address _rnt) ERC20("Escrowed RNT", "esRNT") {
        rnt = RNT(_rnt);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
        userLocks[to].push(Lock(amount, block.timestamp));
    }

    function calculateReleaseable(address user) public view returns (uint256) {
        uint256 total = 0;
        Lock[] memory locks = userLocks[user];
        
        for(uint i = 0; i < locks.length; i++) {
            uint256 timeElapsed = block.timestamp - locks[i].startTime;
            if(timeElapsed >= LOCK_PERIOD) {
                total += locks[i].amount;
            } else {
                total += (locks[i].amount * timeElapsed) / LOCK_PERIOD;
            }
        }
        return total;
    }

    function convert() public {
        uint256 releaseable = calculateReleaseable(msg.sender);
        require(releaseable > 0, "Nothing to convert");
        
        uint256 balance = balanceOf(msg.sender);
        require(balance >= releaseable, "Insufficient balance");

        _burn(msg.sender, balance);
        rnt.mint(msg.sender, releaseable);
        delete userLocks[msg.sender];
    }
}