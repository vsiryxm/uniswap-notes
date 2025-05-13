// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 不检查输入或输出的数学函数
/// @notice 包含执行常见数学函数但不进行任何溢出或下溢检查的方法
library UnsafeMath {
    /// @notice 返回 ceil(x / y)
    /// @dev 除以0的行为未指定，必须在外部检查
    /// @param x 被除数
    /// @param y 除数
    /// @return z 商，ceil(x / y)
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := add(div(x, y), gt(mod(x, y), 0))
        }
    }
}
