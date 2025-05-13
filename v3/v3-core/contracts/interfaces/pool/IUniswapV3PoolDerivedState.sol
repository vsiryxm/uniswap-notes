// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 未存储的池状态
/// @notice 包含视图函数，提供关于池的信息，这些信息是计算得出而非存储在区块链上的。
/// 这里的函数可能有不同的 gas 消耗。
interface IUniswapV3PoolDerivedState {
    /// @notice 返回截至当前区块时间戳的 `secondsAgo` 秒前的累积 tick 和流动性
    /// @dev 要获取时间加权平均 tick 或范围内流动性，你必须使用两个值调用此函数，
    /// 一个表示时间段的开始，另一个表示时间段的结束。例如，要获取最近一小时的时间加权平均 tick，
    /// 你必须使用 secondsAgos = [3600, 0] 调用它。
    /// @dev 时间加权平均 tick 表示池的几何时间加权平均价格，
    /// 以 token1 / token0 的比率的 log base sqrt(1.0001) 表示。TickMath 库可用于将 tick 值转换为比率。
    /// @param secondsAgos 每个累积 tick 和流动性值应从当前区块时间戳前多久返回
    /// @return tickCumulatives 截至当前区块时间戳的每个 `secondsAgos` 的累积 tick 值
    /// @return secondsPerLiquidityCumulativeX128s 截至当前区块时间戳的每个 `secondsAgos` 的累积每单位范围内流动性的秒数值
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice 返回 tick 累积值、每单位流动性秒数和 tick 范围内秒数的快照
    /// @dev 快照只能与其他快照进行比较，且比较的时间段内必须存在头寸。
    /// 也就是说，如果在第一个快照和第二个快照之间的整个时间段内没有持有头寸，则不能比较这些快照。
    /// @param tickLower 范围的下限 tick
    /// @param tickUpper 范围的上限 tick
    /// @return tickCumulativeInside 范围内 tick 累加器的快照
    /// @return secondsPerLiquidityInsideX128 范围内每单位流动性秒数的快照
    /// @return secondsInside 范围内秒数的快照
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}
