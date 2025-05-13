// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

library PoolTicksCounter {
    /// @dev 此函数计算tickBefore和tickAfter之间会产生gas成本的已初始化tick数量。
    /// 当tickBefore和/或tickAfter本身已初始化时，我们是否应该计算它们的逻辑取决于
    /// 交换的方向。如果我们向上交换（tickAfter > tickBefore），我们不想计算tickBefore，但我们确实
    /// 想计算tickAfter。如果我们向下交换，则相反。
    function countInitializedTicksCrossed(
        IUniswapV3Pool self,
        int24 tickBefore,
        int24 tickAfter
    ) internal view returns (uint32 initializedTicksCrossed) {
        int16 wordPosLower;
        int16 wordPosHigher;
        uint8 bitPosLower;
        uint8 bitPosHigher;
        bool tickBeforeInitialized;
        bool tickAfterInitialized;

        {
            // 获取交换前后活跃的tick在tick位图中的键和偏移量。
            int16 wordPos = int16((tickBefore / self.tickSpacing()) >> 8);
            uint8 bitPos = uint8((tickBefore / self.tickSpacing()) % 256);

            int16 wordPosAfter = int16((tickAfter / self.tickSpacing()) >> 8);
            uint8 bitPosAfter = uint8((tickAfter / self.tickSpacing()) % 256);

            // 在tickAfter已初始化的情况下，我们只想在向下交换时计算它。
            // 如果交换后的可初始化tick已初始化，我们的原始tickAfter是
            // tick间距的倍数，并且我们向下交换，我们知道tickAfter已初始化
            // 并且我们不应该计算它。
            tickAfterInitialized =
                ((self.tickBitmap(wordPosAfter) & (1 << bitPosAfter)) > 0) &&
                ((tickAfter % self.tickSpacing()) == 0) &&
                (tickBefore > tickAfter);

            // 在tickBefore已初始化的情况下，我们只想在向上交换时计算它。
            // 使用与上面相同的逻辑来决定是否应该计算tickBefore。
            tickBeforeInitialized =
                ((self.tickBitmap(wordPos) & (1 << bitPos)) > 0) &&
                ((tickBefore % self.tickSpacing()) == 0) &&
                (tickBefore < tickAfter);

            if (wordPos < wordPosAfter || (wordPos == wordPosAfter && bitPos <= bitPosAfter)) {
                wordPosLower = wordPos;
                bitPosLower = bitPos;
                wordPosHigher = wordPosAfter;
                bitPosHigher = bitPosAfter;
            } else {
                wordPosLower = wordPosAfter;
                bitPosLower = bitPosAfter;
                wordPosHigher = wordPos;
                bitPosHigher = bitPos;
            }
        }

        // 通过遍历tick位图来计算穿越的已初始化tick数量。
        // 我们的第一个掩码应该包括较低的tick及其左侧的所有内容。
        uint256 mask = type(uint256).max << bitPosLower;
        while (wordPosLower <= wordPosHigher) {
            // 如果我们在最后的tick位图页上，确保我们只计算到
            // 结束tick。
            if (wordPosLower == wordPosHigher) {
                mask = mask & (type(uint256).max >> (255 - bitPosHigher));
            }

            uint256 masked = self.tickBitmap(wordPosLower) & mask;
            initializedTicksCrossed += countOneBits(masked);
            wordPosLower++;
            // 重置掩码，以便在下一次迭代中考虑所有位。
            mask = type(uint256).max;
        }

        if (tickAfterInitialized) {
            initializedTicksCrossed -= 1;
        }

        if (tickBeforeInitialized) {
            initializedTicksCrossed -= 1;
        }

        return initializedTicksCrossed;
    }

    function countOneBits(uint256 x) private pure returns (uint16) {
        uint16 bits = 0;
        while (x != 0) {
            bits++;
            x &= (x - 1);
        }
        return bits;
    }
}
