// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "forge-std/console.sol";
import "../src/UniswapV2Factory.sol";
import "../src/UniswapV2Pair.sol";
import "../src/test/ERC20.sol";

contract UniswapV2FactoryTest {
    UniswapV2Factory public factory;
    address public wallet;
    address public other;

    address constant TEST_ADDRESS_0 = 0x1000000000000000000000000000000000000000;
    address constant TEST_ADDRESS_1 = 0x2000000000000000000000000000000000000000;

    function setUp() public {
        wallet = address(this);
        other = address(0x1234);
        factory = new UniswapV2Factory(wallet);
    }

    function testFeeToFeeToSetterAllPairsLength() public {
        require(factory.feeTo() == address(0), "feeTo should be zero");
        require(factory.feeToSetter() == wallet, "feeToSetter should be wallet");
        require(factory.allPairsLength() == 0, "allPairsLength should be 0");
    }

    function testCreatePair() public {
        address pairAddress = factory.createPair(TEST_ADDRESS_0, TEST_ADDRESS_1);

        require(factory.getPair(TEST_ADDRESS_0, TEST_ADDRESS_1) == pairAddress, "getPair forward failed");
        require(factory.getPair(TEST_ADDRESS_1, TEST_ADDRESS_0) == pairAddress, "getPair reverse failed");
        require(factory.allPairs(0) == pairAddress, "allPairs failed");
        require(factory.allPairsLength() == 1, "allPairsLength should be 1");

        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        require(pair.factory() == address(factory), "factory mismatch");
        require(pair.token0() == TEST_ADDRESS_0, "token0 mismatch");
        require(pair.token1() == TEST_ADDRESS_1, "token1 mismatch");
    }

    function testCreatePairReverse() public {
        address pairAddress = factory.createPair(TEST_ADDRESS_1, TEST_ADDRESS_0);

        require(factory.getPair(TEST_ADDRESS_0, TEST_ADDRESS_1) == pairAddress, "getPair forward failed");
        require(factory.getPair(TEST_ADDRESS_1, TEST_ADDRESS_0) == pairAddress, "getPair reverse failed");
        require(factory.allPairs(0) == pairAddress, "allPairs failed");
        require(factory.allPairsLength() == 1, "allPairsLength should be 1");

        UniswapV2Pair pair = UniswapV2Pair(pairAddress);
        require(pair.factory() == address(factory), "factory mismatch");
        require(pair.token0() == TEST_ADDRESS_0, "token0 mismatch");
        require(pair.token1() == TEST_ADDRESS_1, "token1 mismatch");
    }

    function testFailCreatePairPairExists() public {
        factory.createPair(TEST_ADDRESS_0, TEST_ADDRESS_1);
        factory.createPair(TEST_ADDRESS_0, TEST_ADDRESS_1); // should revert
    }

    function testSetFeeTo() public {
        factory.setFeeTo(other);
        require(factory.feeTo() == other, "feeTo should be other");
    }

    function testSetFeeToSetter() public {
        factory.setFeeToSetter(other);
        require(factory.feeToSetter() == other, "feeToSetter should be other");
    }
}