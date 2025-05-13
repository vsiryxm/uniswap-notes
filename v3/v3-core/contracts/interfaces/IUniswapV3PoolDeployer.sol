// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title 一个能够部署Uniswap V3池的合约接口
/// @notice 构建池的合约必须实现此接口以向池传递参数
/// @dev 这样做是为了避免在池合约中使用构造函数参数，从而使池的初始代码哈希保持不变，
/// 允许在链上廉价地计算池的CREATE2地址
interface IUniswapV3PoolDeployer {
    /// @notice 获取构建池时使用的参数，在池创建期间暂时设置
    /// @dev 由池构造函数调用以获取池的参数
    /// Returns factory 工厂地址
    /// Returns token0 按地址排序顺序的池中第一个代币
    /// Returns token1 按地址排序顺序的池中第二个代币
    /// Returns fee 在池中每次交换时收取的费用，以百分之一基点（bip）为单位
    /// Returns tickSpacing 已初始化tick之间的最小tick数
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        );
}
