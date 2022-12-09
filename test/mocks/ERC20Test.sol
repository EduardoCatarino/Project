// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Test is ERC20 {
   constructor() ERC20("Token0", "T0"){
        _mint(msg.sender, type(uint256).max);
   }
}