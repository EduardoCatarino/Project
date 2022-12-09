
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@layerzerolabs/token/oft/OFT.sol";

/// @title TheToken
/// @notice This contract is of the reward token for the vault, it works with omnichain
contract TheToken is OFT{
    constructor(address _layerZeroEndpoint) OFT("TheToken", "TT", _layerZeroEndpoint){
        _mint(_msgSender(), type(uint256).max);
    }
}