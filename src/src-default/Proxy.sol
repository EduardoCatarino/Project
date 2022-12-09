// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Storage.sol";

/// @title Proxy
/// @notice This contract is a proxy for the Vault contract
/// @notice It inherits the Storage contract to not have collition with vault, uses ownable for security
contract Proxy is Storage, Ownable{

    /// @notice This function allows the owner to upgrade the vault contract
    function setVaultAddress(address _Vault) public onlyOwner{
        currentOwner = msg.sender;
        vault = _Vault;
    }

    /// @notice This function calls the Vault contract 
    fallback () external payable {
        assembly {
            let _target := sload(0)
            
            calldatacopy(0, 0, calldatasize())
            
            let result := delegatecall(gas(), _target, 0, calldatasize(), 0, 0)
            
            returndatacopy(0, 0, returndatasize())
            
            switch result 
            case 0 {revert(0, returndatasize())} 
            default {return (0, returndatasize())}
        }
    }

    receive() external payable{}
}