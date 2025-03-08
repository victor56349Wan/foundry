// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./erc20Permit.sol";

contract ERC20WithFee is ERC20Permit {
    uint256 public feePercentage; // 手续费百分比，单位为千分之一

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 feePercentage_
    ) ERC20Permit(name_, symbol_, decimals_, totalSupply_) {
        require(feePercentage_ <= 1000, "Fee percentage too high");
        feePercentage = feePercentage_;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint256 fee = (amount * feePercentage) / 1000;
        uint256 amountAfterFee = amount - fee;
        super._transfer(sender, recipient, amountAfterFee);
        super._transfer(sender, address(this), fee); // 将手续费转移到合约地址
    }
}