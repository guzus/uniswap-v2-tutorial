// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../src/UniswapV2Router02.sol";
import "../src/test/ERC20.sol";
import "../src/test/WETH9.sol";

contract DeployScript is Script {
    // Deployment addresses
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;
    ERC20 public tokenA;
    ERC20 public tokenB;
    UniswapV2Pair public pair;

    // Configuration
    uint256 constant TOKEN_A_SUPPLY = 1000000e18; // 1 million tokens
    uint256 constant TOKEN_B_SUPPLY = 1000000e18; // 1 million tokens
    uint256 constant INITIAL_LIQUIDITY_A = 10000e18; // 10k tokens
    uint256 constant INITIAL_LIQUIDITY_B = 10000e18; // 10k tokens

    function run() external {
        // Get the deployer's private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying with address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy WETH
        weth = new WETH9();
        console.log("WETH deployed at:", address(weth));

        // Step 2: Deploy the Factory
        factory = new UniswapV2Factory(deployer);
        console.log("Factory deployed at:", address(factory));
        console.log("Fee setter:", factory.feeToSetter());

        // Step 3: Deploy the Router
        router = new UniswapV2Router02(address(factory), address(weth));
        console.log("Router deployed at:", address(router));
        console.log("Router factory:", router.factory());
        console.log("Router WETH:", router.WETH());

        // Step 4: Deploy two test tokens (for demonstration)
        tokenA = new ERC20("Good Morning", "GM", TOKEN_A_SUPPLY);
        tokenB = new ERC20("Good Night", "GN", TOKEN_B_SUPPLY);
        console.log("Token A (GM) deployed at:", address(tokenA));
        console.log("Token B (GN) deployed at:", address(tokenB));

        // Step 5: Create a pair
        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = UniswapV2Pair(pairAddress);
        console.log("Pair created at:", pairAddress);
        console.log("Token0:", pair.token0());
        console.log("Token1:", pair.token1());

        // Step 6: Add initial liquidity using the router
        tokenA.approve(address(router), INITIAL_LIQUIDITY_A);
        tokenB.approve(address(router), INITIAL_LIQUIDITY_B);

        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            INITIAL_LIQUIDITY_A,
            INITIAL_LIQUIDITY_B,
            0,
            0,
            deployer,
            block.timestamp + 300
        );
        console.log("Initial liquidity added via router:");
        console.log("  Amount A:", amountA);
        console.log("  Amount B:", amountB);
        console.log("  Liquidity:", liquidity);
        console.log("LP token balance:", pair.balanceOf(deployer));

        // Display final reserves
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("Final reserves - Reserve0:", uint256(reserve0));
        console.log("Final reserves - Reserve1:", uint256(reserve1));

        vm.stopBroadcast();

        // Output deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("WETH:", address(weth));
        console.log("Factory:", address(factory));
        console.log("Router:", address(router));
        console.log("Token A (GM):", address(tokenA));
        console.log("Token B (GN):", address(tokenB));
        console.log("GM-GN Pair:", pairAddress);
        console.log("========================\n");
    }
}

contract DeployFactoryOnly is Script {
    UniswapV2Factory public factory;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying Factory with address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy only the Factory
        factory = new UniswapV2Factory(deployer);

        vm.stopBroadcast();

        console.log("\n=== Factory Deployment ===");
        console.log("Factory address:", address(factory));
        console.log("Fee to setter:", factory.feeToSetter());
        console.log("Fee to:", factory.feeTo());
        console.log("All pairs length:", factory.allPairsLength());
        console.log("========================\n");
    }
}

contract DeployAndCreatePool is Script {
    UniswapV2Factory public factory;
    UniswapV2Pair public pair;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get factory address from environment or use default
        address factoryAddress = vm.envOr("FACTORY_ADDRESS", address(0));
        require(factoryAddress != address(0), "FACTORY_ADDRESS not set");

        // Get token addresses
        address token0 = vm.envAddress("TOKEN0_ADDRESS");
        address token1 = vm.envAddress("TOKEN1_ADDRESS");
        require(token0 != address(0), "TOKEN0_ADDRESS not set");
        require(token1 != address(0), "TOKEN1_ADDRESS not set");
        require(token0 != token1, "Tokens must be different");

        console.log("Creating pool with:");
        console.log("Factory:", factoryAddress);
        console.log("Token0:", token0);
        console.log("Token1:", token1);

        vm.startBroadcast(deployerPrivateKey);

        factory = UniswapV2Factory(factoryAddress);

        // Check if pair already exists
        address existingPair = factory.getPair(token0, token1);
        if (existingPair != address(0)) {
            console.log("Pair already exists at:", existingPair);
            pair = UniswapV2Pair(existingPair);
        } else {
            // Create new pair
            address pairAddress = factory.createPair(token0, token1);
            pair = UniswapV2Pair(pairAddress);
            console.log("New pair created at:", pairAddress);
        }

        vm.stopBroadcast();

        console.log("\n=== Pool Creation Summary ===");
        console.log("Pair address:", address(pair));
        console.log("Token0 (sorted):", pair.token0());
        console.log("Token1 (sorted):", pair.token1());
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("Reserve0:", uint256(reserve0));
        console.log("Reserve1:", uint256(reserve1));
        console.log("============================\n");
    }
}

contract AddLiquidity is Script {
    UniswapV2Pair public pair;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get pair address
        address pairAddress = vm.envAddress("PAIR_ADDRESS");
        require(pairAddress != address(0), "PAIR_ADDRESS not set");

        // Get amounts to add
        uint256 amount0 = vm.envOr("AMOUNT0", uint256(1000e18));
        uint256 amount1 = vm.envOr("AMOUNT1", uint256(1000e18));

        pair = UniswapV2Pair(pairAddress);

        console.log("Adding liquidity to pair:", pairAddress);
        console.log("Amount0:", amount0);
        console.log("Amount1:", amount1);

        vm.startBroadcast(deployerPrivateKey);

        // Get token addresses
        address token0 = pair.token0();
        address token1 = pair.token1();

        // Transfer tokens to pair (assumes deployer has tokens)
        ERC20(token0).transfer(pairAddress, amount0);
        ERC20(token1).transfer(pairAddress, amount1);

        // Mint LP tokens
        uint256 liquidity = pair.mint(deployer);

        vm.stopBroadcast();

        console.log("\n=== Liquidity Added ===");
        console.log("LP tokens minted:", liquidity);
        console.log("Your LP balance:", pair.balanceOf(deployer));
        (uint112 reserve0, uint112 reserve1,) = pair.getReserves();
        console.log("New Reserve0:", uint256(reserve0));
        console.log("New Reserve1:", uint256(reserve1));
        console.log("======================\n");
    }
}