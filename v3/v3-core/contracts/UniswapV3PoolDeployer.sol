// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3PoolDeployer.sol';

import './UniswapV3Pool.sol';

contract UniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    struct Parameters {
        address factory;    // 工厂合约地址
        address token0;     // 第一个代币地址（按地址排序）
        address token1;     // 第二个代币地址（按地址排序）
        uint24 fee;         // 交易手续费率
        int24 tickSpacing;  // tick间距
    }

    /// @inheritdoc IUniswapV3PoolDeployer
    Parameters public override parameters;

    /// @dev 通过临时设置参数存储槽然后在部署池后清除它，来部署具有给定参数的池
    /// @param factory Uniswap V3工厂的合约地址
    /// @param token0 池中按地址排序的第一个代币
    /// @param token1 池中按地址排序的第二个代币
    /// @param fee 池中每次交换收取的费用，以百分之一个bip（即百万分之一）为单位
    /// @param tickSpacing 可用tick之间的间距
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        // 解决UniswapV3Pool合约constructor中无法传递struct参数问题
        // 见UniswapV3Pool合约中的调用：(factory, token0, token1, fee, _tickSpacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
        // 执行流程：
        // UniswapV3Factory.createPool
        //     ↓
        // UniswapV3PoolDeployer.deploy
        //     ↓ 设置 parameters
        //     ↓
        // new UniswapV3Pool() 
        //     ↓ 
        // UniswapV3Pool.constructor
        //     ↓ 读取 parameters
        //     ↓
        // delete parameters
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters; // 用完后释放
    }
}