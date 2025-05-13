// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import './FullMath.sol';
import './SqrtPriceMath.sol';

/// @title 计算tick范围内交换结果的库
/// @notice 包含用于计算单个价格范围内（即单个tick）交换结果的方法
library SwapMath {
    /// @notice 根据交换参数计算交换一定数量代币的结果
    /// @dev 当交换的`amountSpecified`为正数时，手续费加上输入数量永远不会超过剩余数量
    /// @param sqrtRatioCurrentX96 池的当前价格（平方根格式）
    /// @param sqrtRatioTargetX96 不能超过的价格上限/下限，用于推断交换方向
    /// @param liquidity 可用的流动性
    /// @param amountRemaining 需要交换的输入或输出代币数量
    /// @param feePips 从输入金额中收取的手续费，以百分之一个基点表示
    /// @return sqrtRatioNextX96 交换后的价格，不会超过目标价格
    /// @return amountIn 需要输入的代币数量，根据交换方向可能是token0或token1
    /// @return amountOut 将收到的代币数量，根据交换方向可能是token0或token1
    /// @return feeAmount 将收取的手续费金额
    function computeSwapStep(
        uint160 sqrtRatioCurrentX96,
        uint160 sqrtRatioTargetX96,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    )
        internal
        pure
        returns (
            uint160 sqrtRatioNextX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtRatioCurrentX96 >= sqrtRatioTargetX96;
        bool exactIn = amountRemaining >= 0;

        if (exactIn) {
            uint256 amountRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
            amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true);
            if (amountRemainingLessFee >= amountIn) sqrtRatioNextX96 = sqrtRatioTargetX96;
            else
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
        } else {
            amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false);
            if (uint256(-amountRemaining) >= amountOut) sqrtRatioNextX96 = sqrtRatioTargetX96;
            else
                sqrtRatioNextX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtRatioCurrentX96,
                    liquidity,
                    uint256(-amountRemaining),
                    zeroForOne
                );
        }

        bool max = sqrtRatioTargetX96 == sqrtRatioNextX96;

        // 获取输入/输出数量
        if (zeroForOne) {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount0Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount1Delta(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false);
        } else {
            amountIn = max && exactIn
                ? amountIn
                : SqrtPriceMath.getAmount1Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false);
        }

        // 限制输出金额不超过剩余输出金额
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        if (exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96) {
            // 未达到目标价格，将最大输入量的剩余部分作为手续费
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            // 计算输入金额对应的手续费
            feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}
