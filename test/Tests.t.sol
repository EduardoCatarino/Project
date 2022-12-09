// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./UniswapTest.sol";

import "src/src-default/Proxy.sol";
import "src/src-default/Vault.sol";
import "src/src-default/TheToken.sol";

/// @title Tests
/// @notice This contract contains tests for the Proxy and Vault contracts
/// @notice It inherits UniswapTest so it can use LPTokens
contract Tests is UniswapTest {
    //contracts
    Proxy public proxy;
    Vault public vault;
    //change to theToken
    TheToken public theToken;

    address public depositer1 = vm.addr(1502);
    address public depositer2 = vm.addr(1503);
    address public depositer3 = vm.addr(1504);
    address public depositer4 = vm.addr(1505);

    //Goerli (Ethereum Testnet)​
    address public layerZeroEndpoint =  0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23;
    
    /// @notice This function inherits the setUp form UniswapTest and sets up Vault usage
    function setUp() public override {
        super.setUp();

        vm.startPrank(deployer);
        //initialize token
        theToken = new TheToken(layerZeroEndpoint);
        
        //initialize contracts
        proxy = new Proxy();
        vault = new Vault();
        proxy.setVaultAddress(address(vault));
        (bool success,) = address(proxy).call(abi.encodeWithSignature("initialize(address,address)",
        LPToken,
        address(theToken)));
        require(success, "Initialize failed");

        //Give necessary tokens to vault and depositers
        theToken.transfer(address(proxy), 10000 ether);

        (success,) =LPToken.call(abi.encodeWithSignature("transfer(address,uint256)", depositer1,100 ether));require(success, "failed");
        (success,) =LPToken.call(abi.encodeWithSignature("transfer(address,uint256)", depositer2,100 ether));require(success, "failed");
        (success,) =LPToken.call(abi.encodeWithSignature("transfer(address,uint256)", depositer3,100 ether));require(success, "failed");
        (success,) =LPToken.call(abi.encodeWithSignature("transfer(address,uint256)", depositer4,100 ether));require(success, "failed");

        vm.stopPrank();
    }

    /// @notice tests the function deposit(address,uint256)
    function testDeposit() public {

        //set Tokens per duration
        vm.startPrank(deployer);
        uint duration = (1/2)*(360*24*60*60); //6 months in seconds
        (bool success,) = address(proxy).call(abi.encodeWithSignature("setTokensPerDuration(uint256,uint256)",50 ether,duration));
        require(success, "Set Tokens per Duration failed");
        vm.stopPrank();

         //depositor 1 deposits 5 ether for 6 months, then 10 ether 1 year
        vm.startPrank(depositer1);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (success, ) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success, "Deposit failed");

        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 10 ether));require(success,"failed");
        (success, ) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,2)); require(success, "Deposit failed");
        vm.stopPrank();

        //depositor 2 deposits 10 ether for 1 year
        vm.startPrank(depositer2);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 10 ether));require(success,"failed");
        (success, ) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",10 ether,2)); require(success, "Deposit failed");
        vm.stopPrank();

        //depositor 3 deposits 20 ether for 2 year
        vm.startPrank(depositer3);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 20 ether));require(success,"failed");
        (success, ) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",20 ether,4)); require(success, "Deposit failed");
        vm.stopPrank();

        //depositor 4 deposits 5 ether for 3 year, then 0 ether for 1 year (both will revert)
        vm.startPrank(depositer4);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        vm.expectRevert();
        (success, ) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,6)); require(success, "Deposit failed");
        
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        vm.expectRevert();
        (success, ) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",0 ether,2)); require(success, "Deposit failed");
        vm.stopPrank();
    }

    /// @notice tests the function withdraw(uint256)
    function testWithdraw() public {
        //set Tokens per duration
        vm.startPrank(deployer);
        uint duration = (1/2)*(360*24*60*60); //6 months in seconds
        (bool success,) = address(proxy).call(abi.encodeWithSignature("setTokensPerDuration(uint256,uint256)",50 ether,duration));
        require(success, "Set Tokens per Duration failed");
        vm.stopPrank();

        //depositor 1 deposits 5 ether for 6 months and tries to withdraw (will revert)
        vm.startPrank(depositer1);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success1, bytes memory data1) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success1, "Deposit failed");
        uint id1 = uint(bytes32(data1));

        vm.expectRevert();
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id1)); require(success, "withdraw failed");
        vm.stopPrank();

        //depositor 2 deposits 5 ether for 6 months, waits 6 months then withdraws
        vm.startPrank(depositer2);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success2, bytes memory data2) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success2, "Deposit failed");
        uint id2 = uint(bytes32(data2));

        vm.warp(block.timestamp + 1/2 * (360*24*60*60)+1);
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id2)); require(success, "withdraw failed");
        vm.stopPrank();

        //depositer 1 waits a year since depositing and withdraws
        vm.startPrank(depositer1);
        vm.warp(block.timestamp + 1/2 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id1)); require(success, "withdraw failed");
        vm.stopPrank();
    }

    /// @notice tests the function getRewards(uint256)
    function testGetRewards() public {
        //set Tokens per duration
        vm.startPrank(deployer);
        uint duration = (1/2)*(360*24*60*60); //6 months in seconds
        (bool success,) = address(proxy).call(abi.encodeWithSignature("setTokensPerDuration(uint256,uint256)",50 ether,duration));
        require(success, "Set Tokens per Duration failed");
        vm.stopPrank();

        //depositor 1 deposits 5 ether for 2 years, and retrieves rewards several times during locked period, tries again after 1 year
        vm.startPrank(depositer1);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success1, bytes memory data1) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,4)); require(success1, "Deposit failed");
        uint id1 = uint(bytes32(data1));

        vm.warp(block.timestamp + 1/2 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");

        vm.warp(block.timestamp + 1/2 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");

        vm.warp(block.timestamp + 1 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer1))/ 1e18, 200 ether/ 1e18);

        vm.warp(block.timestamp + 1 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer1))/ 1e18, 200 ether/ 1e18);
        vm.stopPrank();

        //depositor 2 deposits 5 ether for 6 months, and retrieves rewards after 1 year
        vm.startPrank(depositer2);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success2, bytes memory data2) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success2, "Deposit failed");
        uint id2 = uint(bytes32(data2));

        vm.warp(block.timestamp + 1 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id2)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer2))/ 1e18, 50 ether/ 1e18);
        vm.stopPrank();

    }
/*
    /// @notice tests a simple case with two depositers where one gets rewards halfway and at the end
    function testExample1() public {
        //set Tokens per duration
        vm.startPrank(deployer);
        uint duration = (1/2)*(360*24*60*60); //6 months in seconds
        (bool success,) = address(proxy).call(abi.encodeWithSignature("setTokensPerDuration(uint256,uint256)",50 ether,duration));
        require(success, "Set Tokens per Duration failed");
        vm.stopPrank();

        //depositor 1 deposits 5 ether for 6 months
        vm.startPrank(depositer1);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success1, bytes memory data1) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success1, "Deposit failed");
        uint id1 = uint(bytes32(data1));
        vm.stopPrank();

        //depositor 2 deposits 5 ether for 6 months
        vm.startPrank(depositer2);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success2, bytes memory data2) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success2, "Deposit failed");
        uint id2 = uint(bytes32(data2));
        vm.stopPrank();

        //depositor 1 retrives rewards halfway, and then again at end for a total of 25 ether and withdraws
        vm.startPrank(depositer1);
        vm.warp(block.timestamp + 1/4 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");

        vm.warp(block.timestamp + 1/4 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer1))/ 1e18, 25 ether/ 1e18);
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id1)); require(success, "withdraw failed");
        vm.stopPrank();

        //depositor 2 retrives rewards later for a total of 25 ether and withdraws
        vm.startPrank(depositer2);
        vm.warp(block.timestamp + 1/2 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id2)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer2))/ 1e18, 25 ether/ 1e18);
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id2)); require(success, "withdraw failed");
        vm.stopPrank();
    }

    /// @notice tests a case with two depositers with diferent locking period
    function testExample2() public {
        //set Tokens per duration
        vm.startPrank(deployer);
        uint duration = (1)*(360*24*60*60); //1 year in seconds
        (bool success,) = address(proxy).call(abi.encodeWithSignature("setTokensPerDuration(uint256,uint256)",120 ether,duration));
        require(success, "Set Tokens per Duration failed");
        vm.stopPrank();

        //depositor 1 deposits 5 ether for 6 months
        vm.startPrank(depositer1);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success1, bytes memory data1) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success1, "Deposit failed");
        uint id1 = uint(bytes32(data1));
        vm.stopPrank();

        //depositor 2 deposits 5 ether for 1 year
        vm.startPrank(depositer2);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success2, bytes memory data2) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,2)); require(success2, "Deposit failed");
        uint id2 = uint(bytes32(data2));
        vm.stopPrank();

        //depositor 1 retrives rewards halfway, and then again at end for a total of 20 ether
        vm.startPrank(depositer1);
        vm.warp(block.timestamp + 1/4 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");

        vm.warp(block.timestamp + 1/4 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer1))/ 1e18, 20 ether/ 1e18);
        vm.stopPrank();

        //depositor 2 retrives rewards at 1 year for a total of 100 ether and withdraws
        vm.startPrank(depositer2);
        vm.warp(block.timestamp + 1/2 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id2)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer2))/ 1e18, 100 ether/ 1e18);
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id2)); require(success, "withdraw failed");
        vm.stopPrank();
    }

    /// @notice tests a case with 3 depositers that get rewards at diferent times and withdraw before getting rewards
    function testExample3() public {
        //set Tokens per duration
        vm.startPrank(deployer);
        uint duration = (1)*(360*24*60*60); //1 year in seconds
        (bool success,) = address(proxy).call(abi.encodeWithSignature("setTokensPerDuration(uint256,uint256)",84 ether,duration));
        require(success, "Set Tokens per Duration failed");
        vm.stopPrank();

        //depositor 1 deposits 5 ether for 6 months
        vm.startPrank(depositer1);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success1, bytes memory data1) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success1, "Deposit failed");
        uint id1 = uint(bytes32(data1));
        vm.stopPrank();

        //depositor 2 deposits 5 ether for 1 year
        vm.startPrank(depositer2);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success2, bytes memory data2) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,2)); require(success2, "Deposit failed");
        uint id2 = uint(bytes32(data2));
        vm.stopPrank();

        //depositor 3 deposits 5 ether for 2 year
        vm.startPrank(depositer3);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success10, bytes memory data3) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,4)); require(success10, "Deposit failed");
        uint id3 = uint(bytes32(data3));
        vm.stopPrank();

        //depositor 2 retrives rewards at 1 year for a total of 26 ether and withdraws
        vm.startPrank(depositer2);
        vm.warp(block.timestamp + 1 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id2)); require(success, "withdraw failed");
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id2)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer2))/ 1e18, 26 ether/ 1e18);
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id2)); require(success, "withdraw failed");
        vm.stopPrank();

        //depositor 3 retrives rewards at 2 years for a total of 136 ether and withdraws before getting rewards
        vm.startPrank(depositer3);
        vm.warp(block.timestamp + 1 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id3)); require(success, "withdraw failed");
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id3)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer3))/ 1e18, 136 ether/ 1e18);
        vm.stopPrank();

        //depositor 1 retrives rewards at 2 years and 6 months for a total of 6 ether
        vm.startPrank(depositer1);
        vm.warp(block.timestamp + 1/2 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("withdraw(uint256)",id1)); require(success, "withdraw failed");
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer1))/ 1e18, 6 ether/ 1e18);
        vm.stopPrank();
    }

    /// @notice tests a case with 3 depositers with diferent locking periods who get rewards at diferent times
    function testExample4() public {

        //set Tokens per duration
        vm.startPrank(deployer);
        uint duration = (1)*(360*24*60*60); //1 year in seconds
        (bool success,) = address(proxy).call(abi.encodeWithSignature("setTokensPerDuration(uint256,uint256)",600 ether,duration));
        require(success, "Set Tokens per Duration failed");
        vm.stopPrank();

        //depositor 1 deposits 5 ether for 6 months at 0 month
        vm.startPrank(depositer1);
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success1, bytes memory data1) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,1)); require(success1, "Deposit failed");
        uint id1 = uint(bytes32(data1));
        vm.stopPrank();

        //depositor 2 deposits 5 ether for 1 year at 3 months
        vm.startPrank(depositer2);
        vm.warp(block.timestamp + 1/4 * (360*24*60*60));
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success2, bytes memory data2) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,2)); require(success2, "Deposit failed");
        uint id2 = uint(bytes32(data2));
        vm.stopPrank();

        //depositor 1 retrives rewards at 6 months for a total of 200 ether
        vm.startPrank(depositer1);
        vm.warp(block.timestamp + 1/4 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id1)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer1))/ 1e18, 200 ether/ 1e18);
        vm.stopPrank();

        //depositor 3 deposits 5 ether for 1 year at 1 year
        vm.startPrank(depositer3);
        vm.warp(block.timestamp + (2/4) * (360*24*60*60));
        (success,) = LPToken.call(abi.encodeWithSignature("approve(address,uint256)", address(proxy), 5 ether));require(success,"failed");
        (bool success10, bytes memory data3) = address(proxy).call(abi.encodeWithSignature("deposit(uint256,uint256)",5 ether,2)); require(success10, "Deposit failed");
        uint id3 = uint(bytes32(data3));
        vm.stopPrank();

        //depositor 2 retrives rewards at 1 year 3 months for a total of 400 ether
        vm.startPrank(depositer2);
        vm.warp(block.timestamp + 1/4 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id2)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer2))/ 1e18, 475 ether/ 1e18);
        vm.stopPrank();

        //depositor 3 retrives rewards at 2 years for a total of 525 ether
        vm.startPrank(depositer3);
        vm.warp(block.timestamp + 3/4 * (360*24*60*60));
        (success,) = address(proxy).call(abi.encodeWithSignature("getRewards(uint256)",id3)); require(success, "getRewards failed");
        assertEq((theToken.balanceOf(depositer3))/ 1e18, 525 ether/ 1e18);
        vm.stopPrank();
    }
*/
}
