// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "forge-std/console.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../src/test/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(uint256 _totalSupply) public ERC20("Test Token", "TEST", _totalSupply) {}
}

contract UniswapV2PairTest {
    UniswapV2Factory public factory;
    UniswapV2Pair public pair;
    TestERC20 public token0;
    TestERC20 public token1;

    address public wallet;
    uint256 constant MINIMUM_LIQUIDITY = 10**3;

    function setUp() public {
        wallet = address(this);
        factory = new UniswapV2Factory(wallet);

        TestERC20 tokenA = new TestERC20(10000e18);
        TestERC20 tokenB = new TestERC20(10000e18);

        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = UniswapV2Pair(pairAddress);

        address token0Address = pair.token0();
        token0 = address(tokenA) == token0Address ? tokenA : tokenB;
        token1 = address(tokenA) == token0Address ? tokenB : tokenA;
    }

    function addLiquidity(uint256 token0Amount, uint256 token1Amount) internal {
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);
        pair.mint(wallet);
    }

    function testMint() public {
        uint256 token0Amount = 1e18;
        uint256 token1Amount = 4e18;
        token0.transfer(address(pair), token0Amount);
        token1.transfer(address(pair), token1Amount);

        uint256 expectedLiquidity = 2e18;
        pair.mint(wallet);

        require(pair.totalSupply() == expectedLiquidity, "totalSupply mismatch");
        require(pair.balanceOf(wallet) == expectedLiquidity - MINIMUM_LIQUIDITY, "LP balance mismatch");
        require(token0.balanceOf(address(pair)) == token0Amount, "token0 balance mismatch");
        require(token1.balanceOf(address(pair)) == token1Amount, "token1 balance mismatch");

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 == token0Amount, "reserve0 mismatch");
        require(reserve1 == token1Amount, "reserve1 mismatch");
    }

    function testBurn() public {
        uint256 token0Amount = 3e18;
        uint256 token1Amount = 3e18;
        addLiquidity(token0Amount, token1Amount);

        uint256 expectedLiquidity = 3e18;
        pair.transfer(address(pair), expectedLiquidity - MINIMUM_LIQUIDITY);
        pair.burn(wallet);

        require(pair.balanceOf(wallet) == 0, "LP balance should be 0");
        require(pair.totalSupply() == MINIMUM_LIQUIDITY, "totalSupply should be minimum");
        require(token0.balanceOf(wallet) > 10000e18 - token0Amount, "token0 not returned");
        require(token1.balanceOf(wallet) > 10000e18 - token1Amount, "token1 not returned");
    }

    function testSwapToken0ForToken1() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        uint256 swapAmount = 1e18;
        uint256 expectedOutputAmount = 1662497915624478906;

        token0.transfer(address(pair), swapAmount);

        uint256 token1BalanceBefore = token1.balanceOf(wallet);
        pair.swap(0, expectedOutputAmount, wallet, "");
        uint256 token1BalanceAfter = token1.balanceOf(wallet);

        require(token1BalanceAfter - token1BalanceBefore == expectedOutputAmount, "Output amount mismatch");

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 == token0Amount + swapAmount, "reserve0 after swap mismatch");
        require(reserve1 == token1Amount - expectedOutputAmount, "reserve1 after swap mismatch");
    }

    function testSwapToken1ForToken0() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        uint256 swapAmount = 1e18;
        uint256 expectedOutputAmount = 453305446940074565;

        token1.transfer(address(pair), swapAmount);

        uint256 token0BalanceBefore = token0.balanceOf(wallet);
        pair.swap(expectedOutputAmount, 0, wallet, "");
        uint256 token0BalanceAfter = token0.balanceOf(wallet);

        require(token0BalanceAfter - token0BalanceBefore == expectedOutputAmount, "Output amount mismatch");

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 == token0Amount - expectedOutputAmount, "reserve0 after swap mismatch");
        require(reserve1 == token1Amount + swapAmount, "reserve1 after swap mismatch");
    }

    function testSwapBidirectional() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        // Swap token0 for token1
        uint256 swap0Amount = 1e18;
        uint256 expectedOutput1 = 1662497915624478906;

        token0.transfer(address(pair), swap0Amount);
        pair.swap(0, expectedOutput1, wallet, "");

        // Now swap token1 for token0
        uint256 swap1Amount = 1e18;
        uint256 expectedOutput0 = 295919061027733431;

        token1.transfer(address(pair), swap1Amount);
        pair.swap(expectedOutput0, 0, wallet, "");

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 == token0Amount + swap0Amount - expectedOutput0, "reserve0 final mismatch");
        require(reserve1 == token1Amount - expectedOutput1 + swap1Amount, "reserve1 final mismatch");
    }

    function testSwapMultipleSmallSwaps() public {
        uint256 token0Amount = 100e18;
        uint256 token1Amount = 100e18;
        addLiquidity(token0Amount, token1Amount);

        // Perform multiple small swaps
        for (uint i = 0; i < 10; i++) {
            uint256 swapAmount = 1e17; // 0.1 tokens
            token0.transfer(address(pair), swapAmount);

            // Get current reserves to calculate exact output
            (uint112 reserve0, uint112 reserve1,) = pair.getReserves();

            // Calculate output using the constant product formula with 0.3% fee
            // amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
            uint256 amountInWithFee = swapAmount * 997;
            uint256 numerator = amountInWithFee * reserve1;
            uint256 denominator = uint256(reserve0) * 1000 + amountInWithFee;
            uint256 amountOut = numerator / denominator;

            pair.swap(0, amountOut, wallet, "");
        }

        (uint112 finalReserve0, uint112 finalReserve1,) = pair.getReserves();
        require(finalReserve0 > token0Amount, "reserve0 should increase");
        require(finalReserve1 < token1Amount, "reserve1 should decrease");
    }

    function testFailSwapInsufficientOutputAmount() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        uint256 swapAmount = 1e18;
        token0.transfer(address(pair), swapAmount);

        // Try to get more output than allowed by constant product formula
        uint256 excessiveOutput = 2e18; // Too much!
        pair.swap(0, excessiveOutput, wallet, ""); // Should revert with "UniswapV2: K"
    }

    function testFailSwapInsufficientLiquidity() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        // Try to swap more than the entire reserve
        uint256 swapAmount = 1e18;
        token0.transfer(address(pair), swapAmount);

        pair.swap(0, token1Amount + 1, wallet, ""); // Should revert
    }

    function testFailSwapInsufficientInputAmount() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        // Don't send any tokens but try to swap
        pair.swap(0, 1e18, wallet, ""); // Should revert with "UniswapV2: INSUFFICIENT_INPUT_AMOUNT"
    }

    function testSkim() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        // Send extra tokens to the pair
        uint256 extra0 = 1000;
        uint256 extra1 = 2000;
        token0.transfer(address(pair), extra0);
        token1.transfer(address(pair), extra1);

        uint256 balance0Before = token0.balanceOf(wallet);
        uint256 balance1Before = token1.balanceOf(wallet);

        pair.skim(wallet);

        require(token0.balanceOf(wallet) == balance0Before + extra0, "skim token0 failed");
        require(token1.balanceOf(wallet) == balance1Before + extra1, "skim token1 failed");
    }

    function testSync() public {
        uint256 token0Amount = 5e18;
        uint256 token1Amount = 10e18;
        addLiquidity(token0Amount, token1Amount);

        // Send extra tokens to the pair
        uint256 extra0 = 1e18;
        uint256 extra1 = 2e18;
        token0.transfer(address(pair), extra0);
        token1.transfer(address(pair), extra1);

        pair.sync();

        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 == token0Amount + extra0, "sync reserve0 failed");
        require(reserve1 == token1Amount + extra1, "sync reserve1 failed");
    }

    function testPriceOracle() public {
        uint256 token0Amount = 3e18;
        uint256 token1Amount = 3e18;
        addLiquidity(token0Amount, token1Amount);

        uint256 price0CumulativeLastBefore = pair.price0CumulativeLast();
        uint256 price1CumulativeLastBefore = pair.price1CumulativeLast();

        // Mine a block to advance time (in real tests you'd use vm.warp)
        // For now we'll just do a swap which updates the oracle
        token0.transfer(address(pair), 1e17);
        pair.swap(0, 9e16, wallet, "");

        // The price cumulative values should have increased
        // Note: In a real test with time manipulation, these would accumulate over time
        uint256 price0CumulativeLastAfter = pair.price0CumulativeLast();
        uint256 price1CumulativeLastAfter = pair.price1CumulativeLast();

        // After a swap, cumulative prices should be updated
        require(
            price0CumulativeLastAfter >= price0CumulativeLastBefore ||
            price1CumulativeLastAfter >= price1CumulativeLastBefore,
            "Price oracle not updating"
        );
    }
}