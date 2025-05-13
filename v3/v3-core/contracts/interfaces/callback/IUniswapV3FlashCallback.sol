// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IUniswapV3PoolActions#flash的回调接口
/// @notice 任何调用IUniswapV3PoolActions#flash的合约都必须实现此接口
interface IUniswapV3FlashCallback {
    /// @notice 从IUniswapV3Pool#flash向接收者转账后调用`msg.sender`
    /// @dev 在实现中，你必须向池偿还闪电贷发送的代币加上计算的费用金额。
    /// 此方法的调用者必须验证是由规范的UniswapV3Factory部署的UniswapV3Pool。
    /// @param fee0 闪电贷结束时欠池的token0费用金额
    /// @param fee1 闪电贷结束时欠池的token1费用金额
    /// @param data 调用者通过IUniswapV3PoolActions#flash调用传递的任何数据
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}
