// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./TheToken.sol";

/// @title Storage
/// @notice This contract stores all variables for the proxy and the vault
contract Storage {
    /// @notice Variables for proxy
    address vault;
    address currentOwner;
    bool initialized;

    /// @notice Variables for vault
    address public LPToken;
    TheToken public theToken;

    // emits amount of tokens per duration
    uint tokensPerDuration;

    struct AmountDeposited {  // struct used for mapping
        uint amount; 
        uint lockingPeriod; 
        uint startAt; 
        uint endAt;}
    uint ids; //counter to identify separet deposits from the same address
    uint totalFunds; //total funds locked in the vault
    mapping(address => mapping(uint => AmountDeposited)) public deposits; //mapping with all active deposits (user address => user id => all info of deposit)

    uint lastUpdate; //timestamp of the last time there was a change in the pool
    uint rewardPerToken; //variable with the value of the rewards per token over time
    mapping(address => mapping(uint => uint)) public rewards; //mapping with all rewards to be claimed (user address => user id => amount)
    mapping(address => mapping(uint => uint)) public userStartRewardPerToken; //mapping with ewards per token when a user deposited (user address => user id => amount)

    struct ToUnlock { // struct used for mapping
        address user; 
        uint id; 
        uint endTime;}
    ToUnlock[] public locks; //array with the times when deposits unlock 
    ToUnlock[] public sorted;
    mapping (uint => uint) helper;
}