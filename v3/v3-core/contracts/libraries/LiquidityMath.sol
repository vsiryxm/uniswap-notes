// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 流动性数学库
library LiquidityMath {
    /// @notice 向流动性添加带符号的流动性变化量，如果溢出或下溢则回滚
    /// @param x 变化前的流动性
    /// @param y 流动性应变化的增量，可为正可为负
    /// @return z 流动性变化量
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }
}
