// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import './BytesLib.sol';

/// @title 用于操作多跳交换路径数据的函数
library Path {
    using BytesLib for bytes;

    /// @dev 字节编码地址的长度
    uint256 private constant ADDR_SIZE = 20;
    /// @dev 字节编码费用的长度
    uint256 private constant FEE_SIZE = 3;

    /// @dev 单个代币地址和池费用的偏移量
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + FEE_SIZE;
    /// @dev 编码池键的偏移量
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    /// @dev 包含2个或更多池的编码的最小长度
    uint256 private constant MULTIPLE_POOLS_MIN_LENGTH = POP_OFFSET + NEXT_OFFSET;

    /// @notice 当且仅当路径包含两个或更多池时返回true
    /// @param path 编码的交换路径
    /// @return 如果路径包含两个或更多池则为True，否则为false
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }

    /// @notice 返回路径中的池数量
    /// @param path 编码的交换路径
    /// @return 路径中的池数量
    function numPools(bytes memory path) internal pure returns (uint256) {
        // 忽略第一个代币地址。从那之后每个费用和代币偏移量表示一个池。
        return ((path.length - ADDR_SIZE) / NEXT_OFFSET);
    }

    /// @notice 解码路径中的第一个池
    /// @param path 字节编码的交换路径
    /// @return tokenA 给定池的第一个代币
    /// @return tokenB 给定池的第二个代币
    /// @return fee 池的费用等级
    function decodeFirstPool(bytes memory path)
        internal
        pure
        returns (
            address tokenA,
            address tokenB,
            uint24 fee
        )
    {
        tokenA = path.toAddress(0);
        fee = path.toUint24(ADDR_SIZE);
        tokenB = path.toAddress(NEXT_OFFSET);
    }

    /// @notice 获取对应于路径中第一个池的片段
    /// @param path 字节编码的交换路径
    /// @return 包含定位路径中第一个池所需的所有数据的片段
    function getFirstPool(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(0, POP_OFFSET);
    }

    /// @notice 从缓冲区中跳过一个代币+费用元素并返回剩余部分
    /// @param path 交换路径
    /// @return 路径中剩余的代币+费用元素
    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }
}
