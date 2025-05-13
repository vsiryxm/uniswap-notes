// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import './PoolAddress.sol';

/// @notice 为Uniswap V3池的回调提供验证
library CallbackValidation {
    /// @notice 返回有效的Uniswap V3池的地址
    /// @param factory Uniswap V3工厂的合约地址
    /// @param tokenA token0或token1的合约地址
    /// @param tokenB 另一个代币的合约地址
    /// @param fee 池中每次交换收取的费用，以百分之一个基点（bip）为单位
    /// @return pool V3池合约地址
    function verifyCallback(
        address factory,
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal view returns (IUniswapV3Pool pool) {
        return verifyCallback(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    /// @notice 返回有效的Uniswap V3池的地址
    /// @param factory Uniswap V3工厂的合约地址
    /// @param poolKey V3池的标识键
    /// @return pool V3池合约地址
    function verifyCallback(address factory, PoolAddress.PoolKey memory poolKey)
        internal
        view
        returns (IUniswapV3Pool pool)
    {
        pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
        require(msg.sender == address(pool));
    }
}
