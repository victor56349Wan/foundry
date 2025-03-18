// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract MinimalProxy {
    address immutable implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }
/*
1, deploy ERC20 contract

2, deploy incription to get a proxy contract
3, init run only once proxy contract created 

*/

    fallback() external {
        address impl = implementation;
        require(impl != address(0), "Implementation not set");
        assembly {
            // Delegate call to the implementation contract
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            // Copy the result back
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}