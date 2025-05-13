// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IUniswapV3PoolActions#swap的回调接口
/// @notice 任何调用IUniswapV3PoolActions#swap的合约都必须实现此接口
interface IUniswapV3SwapCallback {
    /// @notice 通过IUniswapV3Pool#swap执行交换后调用`msg.sender`
    /// @dev 在实现中，你必须向池支付交换所欠的代币。
    /// 此方法的调用者必须验证是由规范的UniswapV3Factory部署的UniswapV3Pool。
    /// 如果没有代币被交换，amount0Delta和amount1Delta都可以为0。
    /// @param amount0Delta 池在交换结束前发送（负值）或必须接收（正值）的token0数量。
    /// 如果为正，回调必须向池发送该数量的token0。
    /// @param amount1Delta 池在交换结束前发送（负值）或必须接收（正值）的token1数量。
    /// 如果为正，回调必须向池发送该数量的token1。
    /// @param data 调用者通过IUniswapV3PoolActions#swap调用传递的任何数据
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
