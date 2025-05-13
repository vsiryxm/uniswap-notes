// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// 定义池必须发出的所有事件
interface IUniswapV3PoolEvents {
    /// 池被初始化时发出的事件
    /// @param sqrtPriceX96 初始的平方根价格
    /// @param tick 对应初始价格的tick
    event Initialize(
        uint160 sqrtPriceX96,
        int24 tick
    );

    /// 添加流动性时发出的事件
    /// @param sender 调用mint函数的地址
    /// @param owner 接收流动性的地址
    /// @param tickLower 添加流动性的下限tick
    /// @param tickUpper 添加流动性的上限tick
    /// @param amount 添加的流动性数量
    /// @param amount0 存入的token0数量
    /// @param amount1 存入的token1数量
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// 收集欠款时发出的事件
    /// @param owner 流动性拥有者的地址
    /// @param recipient 接收代币的地址
    /// @param tickLower 流动性位置的下限tick
    /// @param tickUpper 流动性位置的上限tick
    /// @param amount0 收集的token0数量
    /// @param amount1 收集的token1数量
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// 移除流动性时发出的事件
    /// @param owner 拥有流动性的地址
    /// @param tickLower 流动性位置的下限tick
    /// @param tickUpper 流动性位置的上限tick
    /// @param amount 移除的流动性数量
    /// @param amount0 欠债的token0数量
    /// @param amount1 欠债的token1数量
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// 交换发生时发出的事件
    /// @param sender 交换的发起者地址
    /// @param recipient 接收交换输出的地址
    /// @param amount0 池收到的token0净量 (负值表示支出)
    /// @param amount1 池收到的token1净量 (负值表示支出)
    /// @param sqrtPriceX96 交换后的平方根价格
    /// @param liquidity 交换后的流动性
    /// @param tick 交换后的价格对应的tick
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// 闪电贷发生时发出的事件
    /// @param sender 闪电贷的发起者地址
    /// @param recipient 接收闪电贷的地址
    /// @param amount0 借出的token0数量
    /// @param amount1 借出的token1数量
    /// @param paid0 还款的token0数量（包含费用）
    /// @param paid1 还款的token1数量（包含费用）
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// 预言机观察容量增加时发出的事件
    /// @param observationCardinalityNextOld 增加前的下一个观察基数
    /// @param observationCardinalityNextNew 增加后的下一个观察基数
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// 协议费用变更时发出的事件
    /// @param feeProtocol0Old 变更前的token0协议费用
    /// @param feeProtocol1Old 变更前的token1协议费用
    /// @param feeProtocol0New 变更后的token0协议费用
    /// @param feeProtocol1New 变更后的token1协议费用
    event SetFeeProtocol(
        uint8 feeProtocol0Old,
        uint8 feeProtocol1Old,
        uint8 feeProtocol0New,
        uint8 feeProtocol1New
    );

    /// 收集协议费用时发出的事件
    /// @param sender 收集费用的地址（通常是工厂所有者）
    /// @param recipient 接收费用的地址
    /// @param amount0 收集的token0协议费用
    /// @param amount1 收集的token1协议费用
    event CollectProtocol(
        address indexed sender,
        address indexed recipient,
        uint128 amount0,
        uint128 amount1
    );
}
