// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../src/test/ERC20.sol";

contract DeployTest {
    UniswapV2Factory public factory;
    ERC20 public tokenA;
    ERC20 public tokenB;
    UniswapV2Pair public pair;

    function testBasicDeployment() public {
        // Deploy factory
        factory = new UniswapV2Factory(address(this));
        require(address(factory) != address(0), "Factory deployment failed");
        require(factory.feeToSetter() == address(this), "Fee setter incorrect");

        // Deploy tokens
        tokenA = new ERC20(1000000e18);
        tokenB = new ERC20(1000000e18);
        require(address(tokenA) != address(0), "Token A deployment failed");
        require(address(tokenB) != address(0), "Token B deployment failed");

        // Create pair
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        require(pairAddress != address(0), "Pair creation failed");

        pair = UniswapV2Pair(pairAddress);
        require(pair.factory() == address(factory), "Pair factory incorrect");

        // Add liquidity
        tokenA.transfer(pairAddress, 10000e18);
        tokenB.transfer(pairAddress, 10000e18);

        uint256 liquidity = pair.mint(address(this));
        require(liquidity > 0, "No liquidity minted");

        // Check reserves
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        require(reserve0 == 10000e18, "Reserve0 incorrect");
        require(reserve1 == 10000e18, "Reserve1 incorrect");
    }

    function testFactoryPairTracking() public {
        factory = new UniswapV2Factory(address(this));
        tokenA = new ERC20(1000000e18);
        tokenB = new ERC20(1000000e18);

        // Check initial state
        require(factory.allPairsLength() == 0, "Should have no pairs initially");

        // Create pair
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));

        // Check pair is tracked
        require(factory.allPairsLength() == 1, "Should have 1 pair");
        require(factory.allPairs(0) == pairAddress, "Pair not tracked correctly");
        require(factory.getPair(address(tokenA), address(tokenB)) == pairAddress, "getPair failed");
        require(factory.getPair(address(tokenB), address(tokenA)) == pairAddress, "getPair reverse failed");
    }
}