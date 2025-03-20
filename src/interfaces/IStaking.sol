// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    function stake() payable external;
    function unstake(uint256 amount) external;
    function claim() external;
    function balanceOf(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
}
