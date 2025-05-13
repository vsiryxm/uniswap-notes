// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

// 定义池的所有状态变量
interface IUniswapV3PoolState {
    // 返回池的可变状态结构体
    // @return sqrtPriceX96 当前的平方根价格 (Q64.96)
    // @return tick 当前价格对应的tick
    // @return observationIndex 最新观察值的索引
    // @return observationCardinality 当前可用的观察值数量
    // @return observationCardinalityNext 下一个可用的观察值数量
    // @return feeProtocol 协议费用比例
    // @return unlocked 池是否未锁定
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );

    // 返回token0的全局累积费用增长
    // 以Q128.128格式表示每单位流动性收取的token0费用
    function feeGrowthGlobal0X128() external view returns (uint256);

    // 返回token1的全局累积费用增长
    // 以Q128.128格式表示每单位流动性收取的token1费用
    function feeGrowthGlobal1X128() external view returns (uint256);

    // 返回已收集的协议费用
    // @return token0 以token0计算的协议费用
    // @return token1 以token1计算的协议费用
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    // 返回当前池内的总流动性
    function liquidity() external view returns (uint128);

    // 返回特定tick的信息
    // @param tick 要查询的tick索引
    // @return liquidityGross 该tick的总流动性 
    // @return liquidityNet 该tick流动性的净变化
    // @return feeGrowthOutside0X128 该tick外部token0费用增长
    // @return feeGrowthOutside1X128 该tick外部token1费用增长
    // @return tickCumulativeOutside 该tick外部tick累积值
    // @return secondsPerLiquidityOutsideX128 该tick外部每单位流动性秒数累积值
    // @return secondsOutside 该tick外部秒数累积值
    // @return initialized 该tick是否已初始化
    function ticks(
        int24 tick
    ) external view returns (
        uint128 liquidityGross,
        int128 liquidityNet,
        uint256 feeGrowthOutside0X128,
        uint256 feeGrowthOutside1X128,
        int56 tickCumulativeOutside,
        uint160 secondsPerLiquidityOutsideX128,
        uint32 secondsOutside,
        bool initialized
    );

    // 返回tickBitmap的值，用于快速查找已初始化的tick
    // @param wordPosition 要查询的bitmap字的位置
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    // 返回特定地址和价格范围的流动性仓位信息
    // @param key 仓位的哈希键
    // @return _liquidity 仓位的流动性数量
    // @return feeGrowthInside0LastX128 上次更新时内部token0费用增长
    // @return feeGrowthInside1LastX128 上次更新时内部token1费用增长
    // @return tokensOwed0 该仓位拥有的token0数量
    // @return tokensOwed1 该仓位拥有的token1数量
    function positions(
        bytes32 key
    ) external view returns (
        uint128 _liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    );

    // 返回特定索引的预言机观察数据
    // @param index 观察数据的索引
    // @return blockTimestamp 观察时的区块时间戳
    // @return tickCumulative 当时的tick累积值
    // @return secondsPerLiquidityCumulativeX128 当时的每单位流动性秒数累积值
    // @return initialized 该观察是否已初始化
    function observations(
        uint256 index
    ) external view returns (
        uint32 blockTimestamp,
        int56 tickCumulative,
        uint160 secondsPerLiquidityCumulativeX128,
        bool initialized
    );
}
