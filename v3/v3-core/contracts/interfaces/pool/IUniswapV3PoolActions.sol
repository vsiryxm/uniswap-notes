// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 定义池的所有可修改状态的行为/函数
interface IUniswapV3PoolActions {
    /// 初始化池的价格，仅可调用一次
    /// @param sqrtPriceX96 初始的平方根价格 (Q64.96)
    function initialize(uint160 sqrtPriceX96) external;

    /// 在特定价格范围内添加流动性
    /// @param recipient 拥有流动性的地址
    /// @param tickLower 流动性价格范围的下限tick
    /// @param tickUpper 流动性价格范围的上限tick
    /// @param amount 要添加的流动性数量
    /// @param data 任何提供给回调的数据
    /// @return amount0 用户必须发送给池的token0数量
    /// @return amount1 用户必须发送给池的token1数量
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// 从流动性位置收取代币
    /// @param recipient 接收收集的代币的地址
    /// @param tickLower 流动性位置的下限tick
    /// @param tickUpper 流动性位置的上限tick
    /// @param amount0Requested 想要收集的最大token0数量
    /// @param amount1Requested 想要收集的最大token1数量
    /// @return amount0 实际收集的token0数量
    /// @return amount1 实际收集的token1数量
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// 从特定价格范围内移除流动性
    /// @param tickLower 流动性位置的下限tick
    /// @param tickUpper 流动性位置的上限tick
    /// @param amount 要移除的流动性数量
    /// @return amount0 从池中移除的token0数量
    /// @return amount1 从池中移除的token1数量
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// 执行代币交换
    /// @param recipient 接收输出代币的地址
    /// @param zeroForOne 要交换的代币方向 (true为token0换token1, false反之)
    /// @param amountSpecified 用户想要交换的输入/输出代币数量
    /// @param sqrtPriceLimitX96 价格限制，防止执行过多滑点
    /// @param data 任何提供给回调的数据
    /// @return amount0 池净收入的token0数量 (负值表示支出)
    /// @return amount1 池净收入的token1数量 (负值表示支出)
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// 执行闪电贷
    /// @param recipient 接收闪电贷的地址
    /// @param amount0 想要借用的token0数量
    /// @param amount1 想要借用的token1数量
    /// @param data 传递给回调的任何数据
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// 增加预言机观察数组的容量
    /// @param observationCardinalityNext 下一个观察基数
    function increaseObservationCardinalityNext(
        uint16 observationCardinalityNext
    ) external;
}
