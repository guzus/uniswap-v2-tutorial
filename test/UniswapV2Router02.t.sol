// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Router02.sol";
import "../src/UniswapV2Pair.sol";
import "../src/test/ERC20.sol";
import "../src/test/WETH9.sol";

contract UniswapV2Router02Test is Test {
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;
    ERC20 public tokenA;
    ERC20 public tokenB;

    address public alice = address(0x1);
    address public bob = address(0x2);

    uint256 constant INITIAL_SUPPLY = 1000000e18;
    uint256 constant INITIAL_LIQUIDITY = 10000e18;

    function setUp() public {
        // Deploy WETH
        weth = new WETH9();

        // Deploy Factory
        factory = new UniswapV2Factory(address(this));

        // Deploy Router
        router = new UniswapV2Router02(address(factory), address(weth));

        // Deploy test tokens
        tokenA = new ERC20("Token A", "TKA", INITIAL_SUPPLY);
        tokenB = new ERC20("Token B", "TKB", INITIAL_SUPPLY);

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        tokenA.transfer(alice, 100000e18);
        tokenB.transfer(alice, 100000e18);
        tokenA.transfer(bob, 100000e18);
        tokenB.transfer(bob, 100000e18);
    }

    function testRouterDeployment() public {
        assertEq(router.factory(), address(factory));
        assertEq(router.WETH(), address(weth));
    }

    function testAddLiquidity() public {
        vm.startPrank(alice);

        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        assertEq(amountA, INITIAL_LIQUIDITY);
        assertEq(amountB, INITIAL_LIQUIDITY);
        assertGt(liquidity, 0);

        // Verify pair was created
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        assertFalse(pairAddress == address(0));

        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        assertEq(pair.balanceOf(alice), liquidity);

        vm.stopPrank();
    }

    function testAddLiquidityETH() public {
        vm.startPrank(alice);

        tokenA.approve(address(router), INITIAL_LIQUIDITY);

        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        assertEq(amountToken, INITIAL_LIQUIDITY);
        assertEq(amountETH, 10 ether);
        assertGt(liquidity, 0);

        // Verify WETH-TokenA pair was created
        address pairAddress = factory.getPair(address(tokenA), address(weth));
        assertFalse(pairAddress == address(0));

        vm.stopPrank();
    }

    function testSwapExactTokensForTokens() public {
        // First add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();

        // Now swap
        vm.startPrank(bob);
        uint256 swapAmount = 1000e18;
        tokenA.approve(address(router), swapAmount);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 bobTokenBBalanceBefore = tokenB.balanceOf(bob);

        uint[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            bob,
            block.timestamp + 300
        );

        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertEq(tokenB.balanceOf(bob), bobTokenBBalanceBefore + amounts[1]);

        vm.stopPrank();
    }

    function testSwapExactETHForTokens() public {
        // First add liquidity for WETH-TokenA pair
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);

        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();

        // Now swap ETH for tokens
        vm.startPrank(bob);
        uint256 swapAmount = 1 ether;

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        uint256 bobTokenABalanceBefore = tokenA.balanceOf(bob);

        uint[] memory amounts = router.swapExactETHForTokens{value: swapAmount}(
            0,
            path,
            bob,
            block.timestamp + 300
        );

        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertEq(tokenA.balanceOf(bob), bobTokenABalanceBefore + amounts[1]);

        vm.stopPrank();
    }

    function testSwapExactTokensForETH() public {
        // First add liquidity for WETH-TokenA pair
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);

        router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();

        // Now swap tokens for ETH
        vm.startPrank(bob);
        uint256 swapAmount = 1000e18;
        tokenA.approve(address(router), swapAmount);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        uint256 bobETHBalanceBefore = bob.balance;

        uint[] memory amounts = router.swapExactTokensForETH(
            swapAmount,
            0,
            path,
            bob,
            block.timestamp + 300
        );

        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertEq(bob.balance, bobETHBalanceBefore + amounts[1]);

        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        // First add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        (,, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // Get pair address
        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);

        // Approve router to spend LP tokens
        pair.approve(address(router), liquidity);

        uint256 aliceTokenABalanceBefore = tokenA.balanceOf(alice);
        uint256 aliceTokenBBalanceBefore = tokenB.balanceOf(alice);

        // Remove liquidity
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(tokenA.balanceOf(alice), aliceTokenABalanceBefore + amountA);
        assertEq(tokenB.balanceOf(alice), aliceTokenBBalanceBefore + amountB);

        vm.stopPrank();
    }

    function testRemoveLiquidityETH() public {
        // First add liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);

        (,, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        // Get pair address
        address pairAddress = factory.getPair(address(tokenA), address(weth));
        UniswapV2Pair pair = UniswapV2Pair(pairAddress);

        // Approve router to spend LP tokens
        pair.approve(address(router), liquidity);

        uint256 aliceTokenABalanceBefore = tokenA.balanceOf(alice);
        uint256 aliceETHBalanceBefore = alice.balance;

        // Remove liquidity
        (uint amountToken, uint amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 300
        );

        assertGt(amountToken, 0);
        assertGt(amountETH, 0);
        assertEq(tokenA.balanceOf(alice), aliceTokenABalanceBefore + amountToken);
        assertEq(alice.balance, aliceETHBalanceBefore + amountETH);

        vm.stopPrank();
    }

    function testQuote() public {
        uint amountA = 1000e18;
        uint reserveA = 10000e18;
        uint reserveB = 20000e18;

        uint amountB = router.quote(amountA, reserveA, reserveB);
        assertEq(amountB, 2000e18);
    }

    function testGetAmountOut() public {
        uint amountIn = 1000e18;
        uint reserveIn = 10000e18;
        uint reserveOut = 20000e18;

        uint amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);
        assertGt(amountOut, 0);
        // With 0.3% fee, should be slightly less than the quote
        assertLt(amountOut, 2000e18);
    }

    function testGetAmountsOut() public {
        // Setup liquidity first
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.getAmountsOut(1000e18, path);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1000e18);
        assertGt(amounts[1], 0);
    }

    function test_RevertWhen_AddLiquidityExpired() public {
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        // This should fail because deadline is in the past
        vm.expectRevert(bytes("UniswapV2Router: EXPIRED"));
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp - 1
        );

        vm.stopPrank();
    }

    function test_RevertWhen_SwapInsufficientOutput() public {
        // Setup liquidity
        vm.startPrank(alice);
        tokenA.approve(address(router), INITIAL_LIQUIDITY);
        tokenB.approve(address(router), INITIAL_LIQUIDITY);

        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            alice,
            block.timestamp + 300
        );
        vm.stopPrank();

        // Try to swap with unrealistic minimum output
        vm.startPrank(bob);
        uint256 swapAmount = 100e18;
        tokenA.approve(address(router), swapAmount);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        // This should fail because amountOutMin is too high
        vm.expectRevert(bytes("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"));
        router.swapExactTokensForTokens(
            swapAmount,
            10000e18, // Unrealistic minimum output
            path,
            bob,
            block.timestamp + 300
        );

        vm.stopPrank();
    }
}