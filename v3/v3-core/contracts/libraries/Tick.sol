// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

import './LowGasSafeMath.sol';
import './SafeCast.sol';

import './TickMath.sol';
import './LiquidityMath.sol';

/// @title Tick库
/// @notice 包含用于管理tick过程和相关计算的函数
library Tick {
    using LowGasSafeMath for int256;
    using SafeCast for int256;

    // 为每个初始化的独立tick存储的信息
    struct Info {
        // 引用此tick的总头寸流动性
        uint128 liquidityGross;
        // 当从左到右（右到左）穿越tick时添加（减去）的净流动性数量
        int128 liquidityNet;
        // 此tick另一侧（相对于当前tick）的每单位流动性费用增长
        // 仅有相对意义，非绝对值 — 值取决于tick初始化时间
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
        // tick另一侧的累积tick值
        int56 tickCumulativeOutside;
        // tick另一侧（相对于当前tick）的每单位流动性秒数
        // 仅有相对意义，非绝对值 — 值取决于tick初始化时间
        uint160 secondsPerLiquidityOutsideX128;
        // 在tick另一侧（相对于当前tick）度过的秒数
        // 仅有相对意义，非绝对值 — 值取决于tick初始化时间
        uint32 secondsOutside;
        // 如果tick已初始化则为true，即该值完全等同于表达式liquidityGross != 0
        // 这8位用于防止在穿越新初始化的tick时进行新的存储写入
        bool initialized;
    }

    /// @notice 从给定的tick间距导出每个tick的最大流动性
    /// @dev 在池构造函数中执行
    /// @param tickSpacing 所需的tick间距，以tickSpacing的倍数实现
    ///     例如，tickSpacing为3要求每隔3个tick初始化一个，即..., -6, -3, 0, 3, 6, ...
    /// @return 每个tick的最大流动性
    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    /// @notice 检索费用增长数据
    /// @param self 包含所有初始化tick信息的映射
    /// @param tickLower 头寸的下限tick边界
    /// @param tickUpper 头寸的上限tick边界
    /// @param tickCurrent 当前tick
    /// @param feeGrowthGlobal0X128 token0的全时间全局费用增长，每单位流动性
    /// @param feeGrowthGlobal1X128 token1的全时间全局费用增长，每单位流动性
    /// @return feeGrowthInside0X128 头寸tick边界内token0的全时间费用增长，每单位流动性
    /// @return feeGrowthInside1X128 头寸tick边界内token1的全时间费用增长，每单位流动性
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        Info storage lower = self[tickLower];
        Info storage upper = self[tickUpper];

        // 计算下方费用增长
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (tickCurrent >= tickLower) {
            feeGrowthBelow0X128 = lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = lower.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128;
        }

        // 计算上方费用增长
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if (tickCurrent < tickUpper) {
            feeGrowthAbove0X128 = upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upper.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    /// @notice 更新tick并返回tick是否从初始化变为未初始化，或反之
    /// @param self 包含所有初始化tick信息的映射
    /// @param tick 将要更新的tick
    /// @param tickCurrent 当前tick
    /// @param liquidityDelta 当tick从左到右（右到左）穿越时要添加（减少）的新流动性数量
    /// @param feeGrowthGlobal0X128 token0的全时间全局费用增长，每单位流动性
    /// @param feeGrowthGlobal1X128 token1的全时间全局费用增长，每单位流动性
    /// @param secondsPerLiquidityCumulativeX128 池的全时间每max(1, liquidity)秒数
    /// @param tickCumulative 自池首次初始化以来的tick * 经过的时间
    /// @param time 当前区块时间戳转为uint32
    /// @param upper 为更新头寸的上限tick时为true，为更新头寸的下限tick时为false
    /// @param maxLiquidity 单个tick的最大流动性分配
    /// @return flipped tick是否从初始化变为未初始化，或反之
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Tick.Info storage info = self[tick];

        uint128 liquidityGrossBefore = info.liquidityGross;
        uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

        require(liquidityGrossAfter <= maxLiquidity, 'LO');

        flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

        if (liquidityGrossBefore == 0) {
            // 按照惯例，我们假设所有在tick初始化之前的增长都发生在tick的下方
            if (tick <= tickCurrent) {
                info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128;
                info.tickCumulativeOutside = tickCumulative;
                info.secondsOutside = time;
            }
            info.initialized = true;
        }

        info.liquidityGross = liquidityGrossAfter;

        // 当下限（上限）tick从左到右（右到左）穿越时，必须添加（移除）流动性
        info.liquidityNet = upper
            ? int256(info.liquidityNet).sub(liquidityDelta).toInt128()
            : int256(info.liquidityNet).add(liquidityDelta).toInt128();
    }

    /// @notice 清除tick数据
    /// @param self 包含所有初始化tick信息的映射
    /// @param tick 将被清除的tick
    function clear(mapping(int24 => Tick.Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    /// @notice 根据价格变动需要过渡到下一个tick
    /// @param self 包含所有初始化tick信息的映射
    /// @param tick 过渡的目标tick
    /// @param feeGrowthGlobal0X128 token0的全时间全局费用增长，每单位流动性
    /// @param feeGrowthGlobal1X128 token1的全时间全局费用增长，每单位流动性
    /// @param secondsPerLiquidityCumulativeX128 当前每单位流动性的秒数
    /// @param tickCumulative 自池首次初始化以来的tick * 经过的时间
    /// @param time 当前区块时间戳
    /// @return liquidityNet 当tick从左到右（右到左）穿越时添加（减少）的流动性数量
    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint160 secondsPerLiquidityCumulativeX128,
        int56 tickCumulative,
        uint32 time
    ) internal returns (int128 liquidityNet) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsPerLiquidityOutsideX128 = secondsPerLiquidityCumulativeX128 - info.secondsPerLiquidityOutsideX128;
        info.tickCumulativeOutside = tickCumulative - info.tickCumulativeOutside;
        info.secondsOutside = time - info.secondsOutside;
        liquidityNet = info.liquidityNet;
    }
}
