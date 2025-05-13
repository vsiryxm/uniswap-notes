// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Uniswap V3工厂的接口
/// @notice Uniswap V3工厂促进Uniswap V3池的创建并控制协议费用
interface IUniswapV3Factory {
    /// @notice 当工厂的所有者更改时发出的事件
    /// @param oldOwner 所有者更改前的所有者
    /// @param newOwner 所有者更改后的所有者
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice 当创建池时发出的事件
    /// @param token0 按地址排序顺序的池中第一个代币
    /// @param token1 按地址排序顺序的池中第二个代币
    /// @param fee 在池中每次交换时收取的费用，以百分之一基点为单位
    /// @param tickSpacing 已初始化tick之间的最小tick数
    /// @param pool 创建的池的地址
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pool
    );

    /// @notice 当通过工厂启用新的费用金额用于池创建时发出的事件
    /// @param fee 启用的费用，以百分之一基点为单位
    /// @param tickSpacing 用给定费用创建的池的已初始化tick之间的最小tick数
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    /// @notice 返回工厂的当前所有者
    /// @dev 可以由当前所有者通过setOwner更改
    /// @return 工厂所有者的地址
    function owner() external view returns (address);

    /// @notice 返回给定费用金额的tick间距（如果启用），如果未启用则返回0
    /// @dev 费用金额永远不能被删除，因此此值应在调用上下文中被硬编码或缓存
    /// @param fee 启用的费用，以百分之一基点为单位。未启用的费用返回0
    /// @return tick间距
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    /// @notice 返回给定代币对和费用的池地址，如果不存在则返回地址0
    /// @dev tokenA和tokenB可以按token0/token1或token1/token0顺序传入
    /// @param tokenA token0或token1的合约地址
    /// @param tokenB 另一个代币的合约地址
    /// @param fee 在池中每次交换时收取的费用，以百分之一基点为单位
    /// @return pool 池地址
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /// @notice 为给定的两个代币和费用创建池
    /// @param tokenA 所需池中的两个代币之一
    /// @param tokenB 所需池中的另一个代币
    /// @param fee 池的所需费用
    /// @dev tokenA和tokenB可以按任意顺序传入：token0/token1或token1/token0。tickSpacing从费用中检索。
    /// 如果池已存在、费用无效或代币参数无效，调用将回滚。
    /// @return pool 新创建的池的地址
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    /// @notice 更新工厂的所有者
    /// @dev 必须由当前所有者调用
    /// @param _owner 工厂的新所有者
    function setOwner(address _owner) external;

    /// @notice 启用具有给定tickSpacing的费用金额
    /// @dev 一旦启用，费用金额永远不能被删除
    /// @param fee 要启用的费用金额，以百分之一基点为单位（即1e-6）
    /// @param tickSpacing 对使用给定费用金额创建的所有池强制执行的tick之间的间距
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}