// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DexPair.sol";

contract DexFactory {
    mapping(address => address payable) public getPair; // token -> Pair 地址
    address[] public allPairs;
    address public feeTo; // 费用接收地址

    event PairCreated(address indexed token, address pair, uint allPairsLength);

    constructor(address _feeTo) {
        require(_feeTo != address(0), "Invalid feeTo address");
        feeTo = _feeTo;
    }

    function createPair(address token) external returns (address payable pair) {
        require(token != address(0), "Invalid token address");
        require(getPair[token] == address(0), "Pair already exists");

        bytes memory bytecode = type(DexPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        DexPair(pair).initialize(token);
        getPair[token] = pair;
        allPairs.push(pair);

        emit PairCreated(token, pair, allPairs.length);
        return pair;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }
}