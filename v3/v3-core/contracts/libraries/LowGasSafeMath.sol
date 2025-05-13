// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.0;

/// @title 优化的溢出和下溢安全数学运算
/// @notice 包含以最小gas成本执行数学运算的方法，当溢出或下溢时会回滚
library LowGasSafeMath {
    /// @notice 返回 x + y，如果总和溢出uint256则回滚
    /// @param x 被加数
    /// @param y 加数
    /// @return z x和y的和
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    /// @notice 返回 x - y，如果下溢则回滚
    /// @param x 被减数
    /// @param y 减数
    /// @return z x和y的差
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /// @notice 返回 x * y，如果溢出则回滚
    /// @param x 被乘数
    /// @param y 乘数
    /// @return z x和y的乘积
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    /// @notice 返回 x + y，如果溢出或下溢则回滚
    /// @param x 被加数
    /// @param y 加数
    /// @return z x和y的和
    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    /// @notice 返回 x - y，如果溢出或下溢则回滚
    /// @param x 被减数
    /// @param y 减数
    /// @return z x和y的差
    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }
}
