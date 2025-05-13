// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IUniswapV3PoolActions#mint的回调接口
/// @notice 任何调用IUniswapV3PoolActions#mint的合约都必须实现此接口
interface IUniswapV3MintCallback {
    /// @notice 从IUniswapV3Pool#mint向头寸铸造流动性后调用`msg.sender`
    /// @dev 在实现中，你必须向池支付所铸造流动性所欠的代币。
    /// 此方法的调用者必须验证是由规范的UniswapV3Factory部署的UniswapV3Pool。
    /// @param amount0Owed 因铸造流动性而欠池的token0数量
    /// @param amount1Owed 因铸造流动性而欠池的token1数量
    /// @param data 调用者通过IUniswapV3PoolActions#mint调用传递的任何数据
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
