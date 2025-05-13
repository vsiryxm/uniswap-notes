// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import './BitMath.sol';

/// @title 压缩的tick初始化状态库
/// @notice 存储tick索引到其初始化状态的压缩映射
/// @dev 该映射使用int16作为键，因为tick表示为int24，每个字（word）有256个（2^8）值。
library TickBitmap {
    /// @notice 计算映射中存储tick初始化位的位置
    /// @param tick 要计算位置的tick
    /// @return wordPos 包含该位的映射中的键
    /// @return bitPos 存储标志的字中的位位置
    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(tick % 256);
    }

    /// @notice 将给定tick的初始化状态从false翻转为true，或反之
    /// @param self 要翻转tick的映射
    /// @param tick 要翻转的tick
    /// @param tickSpacing 可用tick之间的间距
    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0); // 确保tick符合间距要求
        (int16 wordPos, uint8 bitPos) = position(tick / tickSpacing);
        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;
    }

    /// @notice 返回与给定tick位于同一字（或相邻字）中的下一个初始化tick，
    /// 该tick或者在左侧（小于等于），或者在右侧（大于）给定tick
    /// @param self 计算下一个初始化tick的映射
    /// @param tick 起始tick
    /// @param tickSpacing 可用tick之间的间距
    /// @param lte 是否向左搜索下一个初始化tick（小于等于起始tick）
    /// @return next 离当前tick最多256个tick距离的下一个初始化或未初始化tick
    /// @return initialized 下一个tick是否已初始化，因为函数仅在最多256个tick范围内搜索
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // 向负无穷方向取整

        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(compressed);
            // 当前bitPos位置及其右侧的所有1
            uint256 mask = (1 << bitPos) - 1 + (1 << bitPos);
            uint256 masked = self[wordPos] & mask;

            // 如果当前tick的右侧或当前位置没有初始化的tick，返回该字的最右边
            initialized = masked != 0;
            // 可能发生溢出/下溢，但通过外部限制tickSpacing和tick来防止
            next = initialized
                ? (compressed - int24(bitPos - BitMath.mostSignificantBit(masked))) * tickSpacing
                : (compressed - int24(bitPos)) * tickSpacing;
        } else {
            // 从下一个tick的字开始，因为当前tick的状态无关紧要
            (int16 wordPos, uint8 bitPos) = position(compressed + 1);
            // bitPos位置及其左侧的所有1
            uint256 mask = ~((1 << bitPos) - 1);
            uint256 masked = self[wordPos] & mask;

            // 如果当前tick左侧没有初始化的tick，返回该字的最左边
            initialized = masked != 0;
            // 可能发生溢出/下溢，但通过外部限制tickSpacing和tick来防止
            next = initialized
                ? (compressed + 1 + int24(BitMath.leastSignificantBit(masked) - bitPos)) * tickSpacing
                : (compressed + 1 + int24(type(uint8).max - bitPos)) * tickSpacing;
        }
    }
}
