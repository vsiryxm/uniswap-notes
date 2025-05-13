// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/v3-core/contracts/libraries/FullMath.sol';
import '@uniswap/v3-core/contracts/libraries/UnsafeMath.sol';
import '@uniswap/v3-core/contracts/libraries/FixedPoint96.sol';

/// @title 基于Q64.96格式的sqrt价格和流动性的函数
/// @notice 暴露来自@uniswap/v3-core SqrtPriceMath的两个函数
/// 这些函数使用价格的平方根作为Q64.96格式和流动性来计算增量
library SqrtPriceMathPartial {
    /// @notice 获取两个价格之间的amount0增量
    /// @dev 计算liquidity / sqrt(lower) - liquidity / sqrt(upper),
    /// 即 liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// @param sqrtRatioAX96 一个sqrt价格
    /// @param sqrtRatioBX96 另一个sqrt价格
    /// @param liquidity 可用的流动性数量
    /// @param roundUp 是否向上或向下舍入金额
    /// @return amount0 覆盖两个传入价格之间大小为liquidity的头寸所需的token0数量
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

        require(sqrtRatioAX96 > 0);

        return
            roundUp
                ? UnsafeMath.divRoundingUp(
                    FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
                    sqrtRatioAX96
                )
                : FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
    }

    /// @notice 获取两个价格之间的amount1增量
    /// @dev 计算liquidity * (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 一个sqrt价格
    /// @param sqrtRatioBX96 另一个sqrt价格
    /// @param liquidity 可用的流动性数量
    /// @param roundUp 是否向上舍入金额，或向下舍入
    /// @return amount1 覆盖两个传入价格之间大小为liquidity的头寸所需的token1数量
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            roundUp
                ? FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }
}
