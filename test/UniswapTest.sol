// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "./mocks/ERC20Test.sol";
import "./mocks/WETHTest.sol";

import "forge-std/Test.sol";

/// @title UniswapTests
/// @notice This contract sets up a Uniswap pair 
contract UniswapTest is Test {

    address public factory;
    address public router;
    address public LPToken;

    ERC20Test public token0;
    WETHTest public weth;

    uint256 public constant UNISWAP_INITIAL_TOKEN_RESERVE = 10000 ether;
    uint256 public constant UNISWAP_INITIAL_WETH_RESERVE = 1000 ether;

    // Deployer address
    address public deployer = vm.addr(1501);
    //address public tester = vm.addr(1500);

    /// @notice This function sets up the pair and adds liquidity
    function setUp() public virtual {
        // Label addresses
        vm.label(deployer, "Deployer");

        // Fund deployer wallet
        vm.deal(deployer, 1000 ether);

        vm.startPrank(deployer);

        // setup tokens
        token0 = new ERC20Test();
        weth = new WETHTest();
        vm.label(address(weth), "WETH");
        vm.label(address(token0), "T0");

        //LPTokens = deployCode("UniswapV2ERC20.sol");

        // setup uniswap
        factory = deployCode("UniswapV2Factory.sol", abi.encode(address(0)));

        (, bytes memory number) = factory.call(abi.encodeWithSignature("pairCodeHash()"));
        emit log_bytes(number);

        router = deployCode("UniswapV2Router02.sol", abi.encode(address(factory),address(weth)));
        vm.label(factory, "Factory");
        vm.label(router, "Router");

        // create pair Token0 <-> WETH and add liquidity
        token0.approve(router, UNISWAP_INITIAL_TOKEN_RESERVE);
        (bool success, ) = router.call{value: UNISWAP_INITIAL_WETH_RESERVE}(
            abi.encodeWithSignature(
                "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)", 
                address(token0), 
                UNISWAP_INITIAL_TOKEN_RESERVE, 
                0, 
                0, 
                deployer, 
                block.timestamp * 2
            )
        );
        require(success, "no success");

        // Get the pair to interact with
        (, bytes memory data) = factory.call(abi.encodeWithSignature("getPair(address,address)", address(token0), address(weth)));
        LPToken = abi.decode(data, (address));

        // Sanity check
        (, data) = LPToken.call(abi.encodeWithSignature("balanceOf(address)", deployer));
        uint256 deployerBalance = abi.decode(data, (uint256));
        assertGt(deployerBalance, 0);

        vm.stopPrank();
    }
}