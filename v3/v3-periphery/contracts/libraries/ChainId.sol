// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.0;

/// @title 获取当前链ID的函数
library ChainId {
    /// @dev 获取当前链ID
    /// @return chainId 当前链ID
    function get() internal pure returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
