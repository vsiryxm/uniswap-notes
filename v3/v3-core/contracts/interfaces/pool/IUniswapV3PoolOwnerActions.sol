// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
// 定义池的所有者（工厂拥有者）可以执行的行为
interface IUniswapV3PoolOwnerActions {
    // 设置协议费用比例
    // @param feeProtocol0 token0的协议费用百分比
    // @param feeProtocol1 token1的协议费用百分比
    function setFeeProtocol(
        uint8 feeProtocol0,
        uint8 feeProtocol1
    ) external;

    // 收集已累积的协议费用
    // @param recipient 接收协议费用的地址
    // @param amount0Requested 请求收集的token0协议费用数量
    // @param amount1Requested 请求收集的token1协议费用数量
    // @return amount0 实际收集的token0协议费用
    // @return amount1 实际收集的token1协议费用
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}
