// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './interfaces/IUniswapV3Factory.sol';

import './UniswapV3PoolDeployer.sol';
import './NoDelegateCall.sol';

import './UniswapV3Pool.sol';

/// @title Uniswap V3官方工厂合约
/// @notice 部署Uniswap V3池并管理池协议费用的所有权和控制权
contract UniswapV3Factory is IUniswapV3Factory, UniswapV3PoolDeployer, NoDelegateCall {
    /// @inheritdoc IUniswapV3Factory
    address public override owner;

    /// @inheritdoc IUniswapV3Factory
    mapping(uint24 => int24) public override feeAmountTickSpacing;
    /// @inheritdoc IUniswapV3Factory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);

        // 初始化三种默认费率和对应的tick间距
        feeAmountTickSpacing[500] = 10;   // 0.05% 费率，tick间距为10
        emit FeeAmountEnabled(500, 10);
        feeAmountTickSpacing[3000] = 60;  // 0.3% 费率，tick间距为60
        emit FeeAmountEnabled(3000, 60);
        feeAmountTickSpacing[10000] = 200; // 1% 费率，tick间距为200
        emit FeeAmountEnabled(10000, 200);
    }

    /// @inheritdoc IUniswapV3Factory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);
        // 确保token0的地址小于token1的地址
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0);  // 确保费率有效
        require(getPool[token0][token1][fee] == address(0));  // 确保池不存在
        pool = deploy(address(this), token0, token1, fee, tickSpacing);
        getPool[token0][token1][fee] = pool;
        // 同时填充反向映射，刻意避免比较地址的成本
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    /// @inheritdoc IUniswapV3Factory
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }

    /// @inheritdoc IUniswapV3Factory
    function enableFeeAmount(uint24 fee, int24 tickSpacing) public override {
        require(msg.sender == owner);
        require(fee < 1000000);  // 费率必须小于100%
        // tick间距上限为16384，以防止tickSpacing过大导致
        // TickBitmap#nextInitializedTickWithinOneWord从有效tick溢出int24容器
        // 16384个tick代表了以1个基点的tick计算时超过5倍的价格变化
        require(tickSpacing > 0 && tickSpacing < 16384);
        require(feeAmountTickSpacing[fee] == 0);  // 确保该费率之前未启用

        feeAmountTickSpacing[fee] = tickSpacing;
        emit FeeAmountEnabled(fee, tickSpacing);
    }
}