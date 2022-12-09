// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./Storage.sol";

/// @title StorageV2
/// @notice This contract stores all variables added necessary for the Omnichain functionlity
contract StorageV2 is Storage{
        uint16 dstChainId; //added in V2, to identify the chain to send message
}