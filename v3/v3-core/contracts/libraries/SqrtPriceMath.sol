// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import './LowGasSafeMath.sol';
import './SafeCast.sol';

import './FullMath.sol';
import './UnsafeMath.sol';
import './FixedPoint96.sol';

/// @title 基于Q64.96格式的平方根价格计算函数
/// @notice 包含使用价格平方根（Q64.96格式）和流动性计算交易变化的函数
library SqrtPriceMath {
    using LowGasSafeMath for uint256;
    using SafeCast for uint256;

    /// @notice 根据token0的增减计算新的平方根价格
    /// @dev 总是向上舍入，因为在精确输出情况下（价格上升）我们需要将价格至少提高到足以获得所需的输出数量，
    /// 而在精确输入情况下（价格下降）我们需要较小的价格变动以避免输出过多。
    /// 最精确的计算公式是 liquidity * sqrtPX96 / (liquidity +- amount * sqrtPX96)，
    /// 如果由于溢出无法计算，我们使用 liquidity / (liquidity / sqrtPX96 +- amount)。
    /// @param sqrtPX96 初始价格（即在考虑token0变化之前的价格）
    /// @param liquidity 可用的流动性数量
    /// @param amount 要从虚拟储备中添加或移除的token0数量
    /// @param add 是添加还是移除token0
    /// @return 添加或移除token0后的价格
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // 如果金额为0，短路计算，确保结果等于输入价格
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            uint256 product;
            if ((product = amount * sqrtPX96) / amount == sqrtPX96) {
                uint256 denominator = numerator1 + product;
                if (denominator >= numerator1)
                    // 总是能放入160位
                    return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
            }

            return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96).add(amount)));
        } else {
            uint256 product;
            // 如果乘积溢出，我们知道分母会下溢
            // 另外，需要检查分母是否下溢
            require((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product);
            uint256 denominator = numerator1 - product;
            return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
        }
    }

    /// @notice 根据token1的增减计算新的平方根价格
    /// @dev 总是向下舍入，因为在精确输出情况下（价格下降）我们需要将价格至少降低到足以获得所需的输出数量，
    /// 而在精确输入情况下（价格上升）我们需要较小的价格变动以避免输出过多。
    /// 我们计算的公式在误差范围内接近无损版本：sqrtPX96 +- amount / liquidity
    /// @param sqrtPX96 初始价格（即在考虑token1变化之前）
    /// @param liquidity 可用的流动性数量
    /// @param amount 要从虚拟储备中添加或移除的token1数量
    /// @param add 是添加还是移除token1
    /// @return 添加或移除amount后的价格
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // 如果添加（减去），向下舍入需要向下（向上）舍入商
        // 在两种情况下，对于大多数输入都避免使用mulDiv
        if (add) {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? (amount << FixedPoint96.RESOLUTION) / liquidity
                        : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
                );

            return uint256(sqrtPX96).add(quotient).toUint160();
        } else {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                        : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
                );

            require(sqrtPX96 > quotient);
            // 总是能放入160位
            return uint160(sqrtPX96 - quotient);
        }
    }

    /// @notice 根据token0或token1的输入量计算新的平方根价格
    /// @dev 如果价格或流动性为0，或者新价格超出边界，将抛出异常
    /// @param sqrtPX96 初始价格（即在考虑输入量之前）
    /// @param liquidity 可用的流动性数量
    /// @param amountIn 正在交换的token0或token1的输入数量
    /// @param zeroForOne 交换的是token0还是token1
    /// @return sqrtQX96 添加输入量到token0或token1后的价格
    function getNextSqrtPriceFromInput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // 舍入以确保不超过目标价格
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
                : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
    }

    /// @notice 根据token0或token1的输出量计算新的平方根价格
    /// @dev 如果价格或流动性为0或者新价格超出边界，将抛出异常
    /// @param sqrtPX96 初始价格（在考虑输出量之前）
    /// @param liquidity 可用的流动性数量
    /// @param amountOut 正在交换出的token0或token1的数量
    /// @param zeroForOne 交换的是token0还是token1
    /// @return sqrtQX96 移除token0或token1的输出数量后的价格
    function getNextSqrtPriceFromOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // 舍入以确保超过目标价格
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
                : getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
    }

    /// @notice 计算两个价格之间的token0数量差异
    /// @dev 计算公式为：liquidity / sqrt(lower) - liquidity / sqrt(upper)，
    /// 即 liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// @param sqrtRatioAX96 一个平方根价格
    /// @param sqrtRatioBX96 另一个平方根价格
    /// @param liquidity 可用的流动性数量
    /// @param roundUp 是向上还是向下舍入结果
    /// @return amount0 在两个传入价格之间覆盖流动性头寸所需的token0数量
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

    /// @notice 计算两个价格之间的token1数量差异
    /// @dev 计算公式为：liquidity * (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 一个平方根价格
    /// @param sqrtRatioBX96 另一个平方根价格
    /// @param liquidity 可用的流动性数量
    /// @param roundUp 是向上还是向下舍入金额
    /// @return amount1 在两个传入价格之间覆盖流动性头寸所需的token1数量
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

    /// @notice 获取带符号的token0数量差异的辅助函数
    /// @param sqrtRatioAX96 一个平方根价格
    /// @param sqrtRatioBX96 另一个平方根价格
    /// @param liquidity 计算amount0差异所对应的流动性变化
    /// @return amount0 两个价格之间对应于传入流动性变化的token0数量
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }

    /// @notice 获取带符号的token1数量差异的辅助函数
    /// @param sqrtRatioAX96 一个平方根价格
    /// @param sqrtRatioBX96 另一个平方根价格
    /// @param liquidity 计算amount1差异所对应的流动性变化
    /// @return amount1 两个价格之间对应于传入流动性变化的token1数量
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount1) {
        return
            liquidity < 0
                ? -getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }
}
