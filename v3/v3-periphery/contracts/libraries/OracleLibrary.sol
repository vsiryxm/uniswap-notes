// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0 <0.8.0;

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

/// @title Oracle库
/// @notice 提供与V3池预言机集成的函数
library OracleLibrary {
    /// @notice 计算给定Uniswap V3池的tick和流动性的时间加权平均值
    /// @param pool 我们想要观察的池的地址
    /// @param secondsAgo 从当前时间往前计算时间加权平均值的秒数
    /// @return arithmeticMeanTick 从(block.timestamp - secondsAgo)到block.timestamp的算术平均tick
    /// @return harmonicMeanLiquidity 从(block.timestamp - secondsAgo)到block.timestamp的调和平均流动性
    function consult(address pool, uint32 secondsAgo)
        internal
        view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        require(secondsAgo != 0, 'BP');

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IUniswapV3Pool(pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        arithmeticMeanTick = int24(tickCumulativesDelta / secondsAgo);
        // 总是向负无穷舍入
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % secondsAgo != 0)) arithmeticMeanTick--;

        // 我们在这里使用乘法而不是移位，以确保harmonicMeanLiquidity不会溢出uint128
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }

    /// @notice 给定一个tick和一个代币数量，计算换取的代币数量
    /// @param tick 用于计算报价的Tick值
    /// @param baseAmount 要转换的代币数量
    /// @param baseToken ERC20代币合约的地址，用作baseAmount的计价单位
    /// @param quoteToken ERC20代币合约的地址，用作quoteAmount的计价单位
    /// @return quoteAmount 用baseAmount的baseToken换取的quoteToken数量
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // 如果自乘后不会溢出，则以更好的精度计算quoteAmount
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }

    /// @notice 给定一个池，返回最老的存储观察距今的秒数
    /// @param pool 我们想要观察的Uniswap V3池的地址
    /// @return secondsAgo 存储在池中的最老观察距今的秒数
    function getOldestObservationSecondsAgo(address pool) internal view returns (uint32 secondsAgo) {
        (, , uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();
        require(observationCardinality > 0, 'NI');

        (uint32 observationTimestamp, , , bool initialized) =
            IUniswapV3Pool(pool).observations((observationIndex + 1) % observationCardinality);

        // 如果基数正在增加过程中，下一个索引可能没有初始化
        // 在这种情况下，最老的观察总是在索引0
        if (!initialized) {
            (observationTimestamp, , , ) = IUniswapV3Pool(pool).observations(0);
        }

        secondsAgo = uint32(block.timestamp) - observationTimestamp;
    }

    /// @notice 给定一个池，返回当前区块开始时的tick值
    /// @param pool Uniswap V3池的地址
    /// @return 池在当前区块开始时所处的tick
    function getBlockStartingTickAndLiquidity(address pool) internal view returns (int24, uint128) {
        (, int24 tick, uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();

        // 需要2个观察值来可靠地计算区块开始的tick
        require(observationCardinality > 1, 'NEO');

        // 如果最新的观察发生在过去，那么在这个区块中没有发生改变tick的交易
        // 因此，`slot0`中的tick与当前区块开始时的tick相同。
        // 我们不需要检查这个观察是否已初始化 - 它被保证已初始化。
        (uint32 observationTimestamp, int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128, ) =
            IUniswapV3Pool(pool).observations(observationIndex);
        if (observationTimestamp != uint32(block.timestamp)) {
            return (tick, IUniswapV3Pool(pool).liquidity());
        }

        uint256 prevIndex = (uint256(observationIndex) + observationCardinality - 1) % observationCardinality;
        (
            uint32 prevObservationTimestamp,
            int56 prevTickCumulative,
            uint160 prevSecondsPerLiquidityCumulativeX128,
            bool prevInitialized
        ) = IUniswapV3Pool(pool).observations(prevIndex);

        require(prevInitialized, 'ONI');

        uint32 delta = observationTimestamp - prevObservationTimestamp;
        tick = int24((tickCumulative - prevTickCumulative) / delta);
        uint128 liquidity =
            uint128(
                (uint192(delta) * type(uint160).max) /
                    (uint192(secondsPerLiquidityCumulativeX128 - prevSecondsPerLiquidityCumulativeX128) << 32)
            );
        return (tick, liquidity);
    }

    /// @notice 计算加权算术平均tick的信息
    struct WeightedTickData {
        int24 tick;
        uint128 weight;
    }

    /// @notice 给定一个ticks和权重的数组，计算加权算术平均tick
    /// @param weightedTickData ticks和权重的数组
    /// @return weightedArithmeticMeanTick 加权算术平均tick
    /// @dev `weightedTickData`的每个条目应该代表具有相同底层池代币的池的ticks。如果不是，
    /// 必须格外小心确保ticks是可比较的（包括小数位差异）。
    /// @dev 注意，加权算术平均tick对应于加权几何平均价格。
    function getWeightedArithmeticMeanTick(WeightedTickData[] memory weightedTickData)
        internal
        pure
        returns (int24 weightedArithmeticMeanTick)
    {
        // 累积每个tick与其权重的乘积之和
        int256 numerator;

        // 累积权重之和
        uint256 denominator;

        // 乘积适合152位，所以需要长度约为2**104的数组才能溢出这个逻辑
        for (uint256 i; i < weightedTickData.length; i++) {
            numerator += weightedTickData[i].tick * int256(weightedTickData[i].weight);
            denominator += weightedTickData[i].weight;
        }

        weightedArithmeticMeanTick = int24(numerator / int256(denominator));
        // 总是向负无穷舍入
        if (numerator < 0 && (numerator % int256(denominator) != 0)) weightedArithmeticMeanTick--;
    }

    /// @notice 返回表示`tokens`中第一个条目相对于最后一个条目价格的"合成"tick
    /// @dev 对于计算路径上的相对价格很有用。
    /// @dev 每对相邻的代币必须有一个tick。
    /// @param tokens 代币合约地址
    /// @param ticks ticks，表示`tokens`中每对代币的价格
    /// @return syntheticTick 合成tick，表示`tokens`中最外层代币的相对价格
    function getChainedPrice(address[] memory tokens, int24[] memory ticks)
        internal
        pure
        returns (int256 syntheticTick)
    {
        require(tokens.length - 1 == ticks.length, 'DL');
        for (uint256 i = 1; i <= ticks.length; i++) {
            // 检查代币地址排序顺序，然后将ticks累积到正在运行的合成tick中，确保中间代币"抵消"
            tokens[i - 1] < tokens[i] ? syntheticTick += ticks[i - 1] : syntheticTick -= ticks[i - 1];
        }
    }
}
