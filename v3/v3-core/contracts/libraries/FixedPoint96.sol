// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.4.0;

/// @title FixedPoint96
/// @notice 用于处理二进制定点数的库，参见 https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev 在SqrtPriceMath.sol中使用
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
