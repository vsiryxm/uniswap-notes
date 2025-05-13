// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

// 导入各种接口和库文件
import './interfaces/IUniswapV3Pool.sol';
import './NoDelegateCall.sol';
import './libraries/LowGasSafeMath.sol';
import './libraries/SafeCast.sol';
import './libraries/Tick.sol';
import './libraries/TickBitmap.sol';
import './libraries/Position.sol';
import './libraries/Oracle.sol';
import './libraries/FullMath.sol';
import './libraries/FixedPoint128.sol';
import './libraries/TransferHelper.sol';
import './libraries/TickMath.sol';
import './libraries/LiquidityMath.sol';
import './libraries/SqrtPriceMath.sol';
import './libraries/SwapMath.sol';
import './interfaces/IUniswapV3PoolDeployer.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IERC20Minimal.sol';
import './interfaces/callback/IUniswapV3MintCallback.sol';
import './interfaces/callback/IUniswapV3SwapCallback.sol';
import './interfaces/callback/IUniswapV3FlashCallback.sol';

contract UniswapV3Pool is IUniswapV3Pool, NoDelegateCall {
    // 使用各种库进行安全数学计算和数据管理
    using LowGasSafeMath for uint256;
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using Oracle for Oracle.Observation[65535];

    /// @inheritdoc IUniswapV3PoolImmutables
    address public immutable override factory;  // 工厂合约地址
    /// @inheritdoc IUniswapV3PoolImmutables
    address public immutable override token0;   // 第一个代币地址
    /// @inheritdoc IUniswapV3PoolImmutables
    address public immutable override token1;   // 第二个代币地址
    /// @inheritdoc IUniswapV3PoolImmutables
    uint24 public immutable override fee;       // 交易手续费率

    /// @inheritdoc IUniswapV3PoolImmutables
    int24 public immutable override tickSpacing;  // tick间距

    /// @inheritdoc IUniswapV3PoolImmutables
    uint128 public immutable override maxLiquidityPerTick;  // 每个tick的最大流动性

    // Slot0包含池的关键当前状态变量
    struct Slot0 {
        // 当前价格，表示为平方根价格 * 2^96
        uint160 sqrtPriceX96;
        // 当前tick
        int24 tick;
        // 最近更新的观察数组索引
        uint16 observationIndex;
        // 当前存储的观察最大数量
        uint16 observationCardinality;
        // 下一个存储的观察最大数量，在observations.write中触发
        uint16 observationCardinalityNext;
        // 当前协议费用，作为提款时收取的交换费用的百分比
        // 表示为整数分母 (1/x)%
        uint8 feeProtocol;
        // 池是否被锁定
        bool unlocked;
    }
    /// @inheritdoc IUniswapV3PoolState
    Slot0 public override slot0;

    /// @inheritdoc IUniswapV3PoolState
    uint256 public override feeGrowthGlobal0X128;  // token0的全局累积费用增长
    /// @inheritdoc IUniswapV3PoolState
    uint256 public override feeGrowthGlobal1X128;  // token1的全局累积费用增长

    // 协议费用（以token0/token1单位累积）
    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }
    /// @inheritdoc IUniswapV3PoolState
    ProtocolFees public override protocolFees;

    /// @inheritdoc IUniswapV3PoolState
    uint128 public override liquidity;  // 当前池中的流动性总量

    /// @inheritdoc IUniswapV3PoolState
    mapping(int24 => Tick.Info) public override ticks;  // 存储每个tick的信息
    /// @inheritdoc IUniswapV3PoolState
    mapping(int16 => uint256) public override tickBitmap;  // 存储tick的位图，用于快速查找下一个初始化的tick
    /// @inheritdoc IUniswapV3PoolState
    mapping(bytes32 => Position.Info) public override positions;  // 存储用户仓位信息
    /// @inheritdoc IUniswapV3PoolState
    Oracle.Observation[65535] public override observations;  // 存储历史价格观察数据，用于预言机

    /// @dev 互斥的重入保护，防止进入池的方法前/后重入。这个方法还防止在池初始化之前进入函数。
    /// 整个合约都需要重入保护，因为我们使用余额检查来确定交互（如mint、swap和flash）的支付状态。
    modifier lock() {
        require(slot0.unlocked, 'LOK');
        slot0.unlocked = false;
        _;
        slot0.unlocked = true;
    }

    /// @dev 防止除IUniswapV3Factory#owner()返回的地址之外的任何人调用函数
    modifier onlyFactoryOwner() {
        require(msg.sender == IUniswapV3Factory(factory).owner());
        _;
    }

    constructor() {
        int24 _tickSpacing;
        (factory, token0, token1, fee, _tickSpacing) = IUniswapV3PoolDeployer(msg.sender).parameters();
        tickSpacing = _tickSpacing;

        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(_tickSpacing);
    }

    /// @dev 检查tick输入的有效性
    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        require(tickLower < tickUpper, 'TLU');  // 下限tick必须小于上限tick
        require(tickLower >= TickMath.MIN_TICK, 'TLM');  // 下限tick必须大于等于最小tick
        require(tickUpper <= TickMath.MAX_TICK, 'TUM');  // 上限tick必须小于等于最大tick
    }

    /// @dev 返回截断为32位的区块时间戳，即mod 2**32。在测试中会重写此方法。
    function _blockTimestamp() internal view virtual returns (uint32) {
        return uint32(block.timestamp); // 截断是有意的
    }

    /// @dev 获取池中token0的余额
    /// @dev 此函数经过燃气优化，避免了除了返回数据大小检查之外的冗余extcodesize检查
    function balance0() private view returns (uint256) {
        (bool success, bytes memory data) =
            token0.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev 获取池中token1的余额
    /// @dev 此函数经过燃气优化，避免了除了返回数据大小检查之外的冗余extcodesize检查
    function balance1() private view returns (uint256) {
        (bool success, bytes memory data) =
            token1.staticcall(abi.encodeWithSelector(IERC20Minimal.balanceOf.selector, address(this)));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @inheritdoc IUniswapV3PoolDerivedState
    // - 这个函数是预言机功能的核心，用于获取特定价格范围内的累积值
    // - 累积值包括：tick累积值、每单位流动性的秒数累积值，以及在该范围内的总秒数
    // - 根据当前价格位于范围外（低于下限、高于上限）还是范围内，使用不同的计算方法
    // - 这些累积值可用于计算TWAP（时间加权平均价格）和其他分析指标
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        override
        noDelegateCall
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        )
    {
        // 检查传入的tick范围是否有效
        checkTicks(tickLower, tickUpper);

        // 声明储存累积值的变量
        int56 tickCumulativeLower;
        int56 tickCumulativeUpper;
        uint160 secondsPerLiquidityOutsideLowerX128;
        uint160 secondsPerLiquidityOutsideUpperX128;
        uint32 secondsOutsideLower;
        uint32 secondsOutsideUpper;

        {
            // 读取下限tick和上限tick的信息
            Tick.Info storage lower = ticks[tickLower];
            Tick.Info storage upper = ticks[tickUpper];
            bool initializedLower;
            (tickCumulativeLower, secondsPerLiquidityOutsideLowerX128, secondsOutsideLower, initializedLower) = (
                lower.tickCumulativeOutside,
                lower.secondsPerLiquidityOutsideX128,
                lower.secondsOutside,
                lower.initialized
            );
            require(initializedLower);  // 要求下限tick已被初始化

            bool initializedUpper;
            (tickCumulativeUpper, secondsPerLiquidityOutsideUpperX128, secondsOutsideUpper, initializedUpper) = (
                upper.tickCumulativeOutside,
                upper.secondsPerLiquidityOutsideX128,
                upper.secondsOutside,
                upper.initialized
            );
            require(initializedUpper);  // 要求上限tick已被初始化
        }

        // 获取当前池状态
        Slot0 memory _slot0 = slot0;

        // 根据当前价格相对于提供的价格范围的位置，计算范围内的累积值
        if (_slot0.tick < tickLower) {
            // 如果当前tick小于下限tick，范围内的累积值是两个边界"outside"值的差
            return (
                tickCumulativeLower - tickCumulativeUpper,
                secondsPerLiquidityOutsideLowerX128 - secondsPerLiquidityOutsideUpperX128,
                secondsOutsideLower - secondsOutsideUpper
            );
        } else if (_slot0.tick < tickUpper) {
            // 如果当前tick在范围内，需要获取当前的观察值，然后进行计算
            uint32 time = _blockTimestamp();
            (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                observations.observeSingle(
                    time,
                    0,
                    _slot0.tick,
                    _slot0.observationIndex,
                    liquidity,
                    _slot0.observationCardinality
                );
            return (
                tickCumulative - tickCumulativeLower - tickCumulativeUpper,
                secondsPerLiquidityCumulativeX128 -
                    secondsPerLiquidityOutsideLowerX128 -
                    secondsPerLiquidityOutsideUpperX128,
                time - secondsOutsideLower - secondsOutsideUpper
            );
        } else {
            // 如果当前tick大于上限tick，同样计算两个边界值的差
            return (
                tickCumulativeUpper - tickCumulativeLower,
                secondsPerLiquidityOutsideUpperX128 - secondsPerLiquidityOutsideLowerX128,
                secondsOutsideUpper - secondsOutsideLower
            );
        }
    }

    /// @inheritdoc IUniswapV3PoolDerivedState
    // 预言机核心
    // - 这是预言机的主要外部接口，允许查询过去任意时间点的价格数据
    // - `secondsAgos` 参数指定要查询的过去时间点列表（相对于当前时间）
    // - 返回每个时间点的 tick 累积值和每单位流动性的秒数累积值
    // - 这些数据可用于计算任意时间段的TWAP
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        noDelegateCall
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        // 使用观察库来获取历史数据
        return
            observations.observe(
                _blockTimestamp(),
                secondsAgos,
                slot0.tick,
                slot0.observationIndex,
                liquidity,
                slot0.observationCardinality
            );
    }

    /// @inheritdoc IUniswapV3PoolActions
    // 增加预言机观察数组的容量，以存储更多的历史价格点
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext)
        external
        override
        lock
        noDelegateCall
    {
        // 记录旧的观察基数（用于事件）
        uint16 observationCardinalityNextOld = slot0.observationCardinalityNext;
        // 增加观察数组的容量
        uint16 observationCardinalityNextNew =
            observations.grow(observationCardinalityNextOld, observationCardinalityNext);
        slot0.observationCardinalityNext = observationCardinalityNextNew;
        // 如果容量实际上改变了，则发出事件
        if (observationCardinalityNextOld != observationCardinalityNextNew)
            emit IncreaseObservationCardinalityNext(observationCardinalityNextOld, observationCardinalityNextNew);
    }

    /// @inheritdoc IUniswapV3PoolActions
    /// @dev 不加锁，因为它初始化时是解锁的
    // 池初始化函数，设置初始价格和相关状态
    function initialize(uint160 sqrtPriceX96) external override {
        // 确保池尚未初始化
        require(slot0.sqrtPriceX96 == 0, 'AI');

        // 根据提供的平方根价格计算对应的tick
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        // 初始化观察数组
        (uint16 cardinality, uint16 cardinalityNext) = observations.initialize(_blockTimestamp());

        // 设置初始状态
        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            observationIndex: 0,
            observationCardinality: cardinality,
            observationCardinalityNext: cardinalityNext,
            feeProtocol: 0,
            unlocked: true
        });

        emit Initialize(sqrtPriceX96, tick);
    }

    struct ModifyPositionParams {
        // 拥有仓位的地址
        address owner;
        // 仓位的下限和上限tick
        int24 tickLower;
        int24 tickUpper;
        // 流动性变化量
        int128 liquidityDelta;
    }

    /// @dev 对仓位进行一些更改
    /// @param params 仓位详情和要改变的流动性
    /// @return position 指向给定所有者和tick范围的仓位的存储指针
    /// @return amount0 欠池的token0数量，如果为负则池应支付给接收者
    /// @return amount1 欠池的token1数量，如果为负则池应支付给接收者
    // - 这是流动性管理的核心函数，处理添加和移除流动性
    // - 根据当前价格与提供的价格范围的关系，计算需要提供的代币数量
    // - 更新相关的状态变量，包括仓位信息、流动性和预言机数据
    function _modifyPosition(ModifyPositionParams memory params)
        private
        noDelegateCall
        returns (
            Position.Info storage position,
            int256 amount0,
            int256 amount1
        )
    {
        // 检查tick范围是否有效
        checkTicks(params.tickLower, params.tickUpper);

        Slot0 memory _slot0 = slot0; // 为优化gas消耗而加载到内存

        // 更新仓位信息
        position = _updatePosition(
            params.owner,
            params.tickLower,
            params.tickUpper,
            params.liquidityDelta,
            _slot0.tick
        );

        // 如果有流动性变化，计算所需代币数量
        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                // 当前tick低于仓位范围；流动性只能通过价格从左向右移动进入范围
                // 这时需要更多的token0（因为它变得更有价值），所以用户必须提供它
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // 当前tick在仓位范围内
                uint128 liquidityBefore = liquidity; // 为优化gas消耗而加载

                // 写入一个预言机条目
                (slot0.observationIndex, slot0.observationCardinality) = observations.write(
                    _slot0.observationIndex,
                    _blockTimestamp(),
                    _slot0.tick,
                    liquidityBefore,
                    _slot0.observationCardinality,
                    _slot0.observationCardinalityNext
                );

                // 计算两种代币的数量
                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );

                // 更新全局流动性
                liquidity = LiquidityMath.addDelta(liquidityBefore, params.liquidityDelta);
            } else {
                // 当前tick高于仓位范围；流动性只能通过价格从右向左移动进入范围
                // 这时需要更多的token1（因为它变得更有价值），所以用户必须提供它
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    /// @dev Gets and updates a position with the given liquidity delta
    /// @param owner the owner of the position
    /// @param tickLower the lower tick of the position's tick range
    /// @param tickUpper the upper tick of the position's tick range
    /// @param tick the current tick, passed to avoid sloads
    function _updatePosition(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Info storage position) {
        position = positions.get(owner, tickLower, tickUpper);

        uint256 _feeGrowthGlobal0X128 = feeGrowthGlobal0X128; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthGlobal1X128; // SLOAD for gas optimization

        // if we need to update the ticks, do it
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            uint32 time = _blockTimestamp();
            (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) =
                observations.observeSingle(
                    time,
                    0,
                    slot0.tick,
                    slot0.observationIndex,
                    liquidity,
                    slot0.observationCardinality
                );

            flippedLower = ticks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                false,
                maxLiquidityPerTick
            );
            flippedUpper = ticks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                secondsPerLiquidityCumulativeX128,
                tickCumulative,
                time,
                true,
                maxLiquidityPerTick
            );

            if (flippedLower) {
                tickBitmap.flipTick(tickLower, tickSpacing);
            }
            if (flippedUpper) {
                tickBitmap.flipTick(tickUpper, tickSpacing);
            }
        }

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
            ticks.getFeeGrowthInside(tickLower, tickUpper, tick, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128);

        position.update(liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                ticks.clear(tickLower);
            }
            if (flippedUpper) {
                ticks.clear(tickUpper);
            }
        }
    }

    /// @inheritdoc IUniswapV3PoolActions
    /// @dev noDelegateCall通过_modifyPosition间接应用
    // 添加流动性的外部接口，将代币存入池并增加仓位流动性
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        // 确保数量大于0
        require(amount > 0);
        
        // 调用核心修改函数
        (, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: recipient,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: int256(amount).toInt128()
                })
            );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        // 处理支付逻辑
        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        
        // 调用回调让调用者转入所需代币
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);
        
        // 确认代币已正确转入
        if (amount0 > 0) require(balance0Before.add(amount0) <= balance0(), 'M0');
        if (amount1 > 0) require(balance1Before.add(amount1) <= balance1(), 'M1');

        emit Mint(msg.sender, recipient, tickLower, tickUpper, amount, amount0, amount1);
    }

    /// @inheritdoc IUniswapV3PoolActions
    // 收集燃烧流动性后欠款的接口，将代币转给接收者
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock returns (uint128 amount0, uint128 amount1) {
        // 获取发送者的仓位
        Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);

        // 计算实际可收取的金额
        amount0 = amount0Requested > position.tokensOwed0 ? position.tokensOwed0 : amount0Requested;
        amount1 = amount1Requested > position.tokensOwed1 ? position.tokensOwed1 : amount1Requested;

        // 更新欠款并转账
        if (amount0 > 0) {
            position.tokensOwed0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            position.tokensOwed1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit Collect(msg.sender, recipient, tickLower, tickUpper, amount0, amount1);
    }

    /// @inheritdoc IUniswapV3PoolActions
    /// @dev noDelegateCall通过_modifyPosition间接应用
    // 移除流动性的外部接口，减少仓位流动性并记录欠款
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external override lock returns (uint256 amount0, uint256 amount1) {
        // 调用核心修改函数，使用负的流动性变化量
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) =
            _modifyPosition(
                ModifyPositionParams({
                    owner: msg.sender,
                    tickLower: tickLower,
                    tickUpper: tickUpper,
                    liquidityDelta: -int256(amount).toInt128()
                })
            );

        // 转为正数，因为从池中取出是负的
        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        // 更新欠款，但不立即转账（需要调用collect）
        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) = (
                position.tokensOwed0 + uint128(amount0),
                position.tokensOwed1 + uint128(amount1)
            );
        }

        emit Burn(msg.sender, tickLower, tickUpper, amount, amount0, amount1);
    }

    struct SwapCache {
        // the protocol fee for the input token
        uint8 feeProtocol;
        // liquidity at the beginning of the swap
        uint128 liquidityStart;
        // the timestamp of the current block
        uint32 blockTimestamp;
        // the current value of the tick accumulator, computed only if we cross an initialized tick
        int56 tickCumulative;
        // the current value of seconds per liquidity accumulator, computed only if we cross an initialized tick
        uint160 secondsPerLiquidityCumulativeX128;
        // whether we've computed and cached the above two accumulators
        bool computedLatestObservation;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // amount of input token paid as protocol fee
        uint128 protocolFee;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    /// @inheritdoc IUniswapV3PoolActions
    // - 这是交易的核心函数，处理代币间的交换
    // - 使用迭代方法计算交换结果，每次迭代计算一个价格区间内的数量
    // - 自动跨越价格区间（tick），更新流动性和费用状态
    // - 内置预言机的数据更新，为TWAP计算提供支持
    // - 支持两种交易模式：精确输入和精确输出
    // - 通过回调机制要求调用者支付代币
    function swap(
        address recipient,
        bool zeroForOne,  // true: token0 -> token1, false: token1 -> token0
        int256 amountSpecified,  // 正值表示精确输入，负值表示精确输出
        uint160 sqrtPriceLimitX96,  // 价格限制
        bytes calldata data
    ) external override noDelegateCall returns (int256 amount0, int256 amount1) {
        // 确保指定金额不为0
        require(amountSpecified != 0, 'AS');

        // 保存初始状态以供使用
        Slot0 memory slot0Start = slot0;

        // 验证锁定状态和价格限制
        require(slot0Start.unlocked, 'LOK');
        require(
            zeroForOne
                ? sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            'SPL'
        );

        // 锁定合约，防止重入
        slot0.unlocked = false;

        // 初始化交换缓存
        SwapCache memory cache =
            SwapCache({
                liquidityStart: liquidity,
                blockTimestamp: _blockTimestamp(),
                feeProtocol: zeroForOne ? (slot0Start.feeProtocol % 16) : (slot0Start.feeProtocol >> 4),
                secondsPerLiquidityCumulativeX128: 0,
                tickCumulative: 0,
                computedLatestObservation: false
            });

        // 确定是精确输入还是精确输出
        bool exactInput = amountSpecified > 0;

        // 初始化交换状态
        SwapState memory state =
            SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: slot0Start.sqrtPriceX96,
                tick: slot0Start.tick,
                feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
                protocolFee: 0,
                liquidity: cache.liquidityStart
            });

        // 只要还有待交换的数量且未达到价格限制，继续交换循环
        while (state.amountSpecifiedRemaining != 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            // 初始化步骤计算结构
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            // 寻找下一个初始化的tick
            (step.tickNext, step.initialized) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                tickSpacing,
                zeroForOne
            );

            // 确保不超出最小/最大tick
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            // 获取下一个tick的价格
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // 计算本次步骤的交换数据
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            // 更新剩余数量和计算结果
            if (exactInput) {
                state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
                state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
            } else {
                state.amountSpecifiedRemaining += step.amountOut.toInt256();
                state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
            }

            // 处理协议费用
            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (cache.feeProtocol > 0) {
                uint256 delta = step.feeAmount / cache.feeProtocol;
                step.feeAmount -= delta;
                state.protocolFee += uint128(delta);
            }

            // 更新全局费用追踪器
            if (state.liquidity > 0)
                state.feeGrowthGlobalX128 += FullMath.mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);

            // 如果达到下一个价格，更新tick
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // 如果tick已初始化，处理tick跨越
                if (step.initialized) {
                    // 处理观察数据和ticks跨越
                    // check for the placeholder value, which we replace with the actual value the first time the swap
                    // crosses an initialized tick
                    if (!cache.computedLatestObservation) {
                        (cache.tickCumulative, cache.secondsPerLiquidityCumulativeX128) = observations.observeSingle(
                            cache.blockTimestamp,
                            0,
                            slot0Start.tick,
                            slot0Start.observationIndex,
                            cache.liquidityStart,
                            slot0Start.observationCardinality
                        );
                        cache.computedLatestObservation = true;
                    }
                    int128 liquidityNet =
                        ticks.cross(
                            step.tickNext,
                            (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                            (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128),
                            cache.secondsPerLiquidityCumulativeX128,
                            cache.tickCumulative,
                            cache.blockTimestamp
                        );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    if (zeroForOne) liquidityNet = -liquidityNet;

                    state.liquidity = LiquidityMath.addDelta(state.liquidity, liquidityNet);
                }

                state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // 如果价格改变但未达到下一个tick，重新计算当前tick
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
        }

        // 如果tick发生变化，更新tick并写入预言机条目
        if (state.tick != slot0Start.tick) {
            // 更新观察数据和slot0
            (uint16 observationIndex, uint16 observationCardinality) =
                observations.write(
                    slot0Start.observationIndex,
                    cache.blockTimestamp,
                    slot0Start.tick,
                    cache.liquidityStart,
                    slot0Start.observationCardinality,
                    slot0Start.observationCardinalityNext
                );
            (slot0.sqrtPriceX96, slot0.tick, slot0.observationIndex, slot0.observationCardinality) = (
                state.sqrtPriceX96,
                state.tick,
                observationIndex,
                observationCardinality
            );
        } else {
            // 否则只更新价格
            slot0.sqrtPriceX96 = state.sqrtPriceX96;
        }

        // 如果流动性改变，更新liquidity
        if (cache.liquidityStart != state.liquidity) liquidity = state.liquidity;

        // 更新费用增长全局变量和协议费用
        // update fee growth global and, if necessary, protocol fees
        // overflow is acceptable, protocol has to withdraw before it hits type(uint128).max fees
        if (zeroForOne) {
            feeGrowthGlobal0X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token0 += state.protocolFee;
        } else {
            feeGrowthGlobal1X128 = state.feeGrowthGlobalX128;
            if (state.protocolFee > 0) protocolFees.token1 += state.protocolFee;
        }

        // 计算最终的交换数量
        (amount0, amount1) = zeroForOne == exactInput
            ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
            : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);

        // 执行转账并收取付款
        if (zeroForOne) {
            if (amount1 < 0) TransferHelper.safeTransfer(token1, recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            require(balance0Before.add(uint256(amount0)) <= balance0(), 'IIA');
        } else {
            if (amount0 < 0) TransferHelper.safeTransfer(token0, recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            require(balance1Before.add(uint256(amount1)) <= balance1(), 'IIA');
        }

        emit Swap(msg.sender, recipient, amount0, amount1, state.sqrtPriceX96, state.liquidity, state.tick);
        slot0.unlocked = true;
    }

    /// @inheritdoc IUniswapV3PoolActions
    // 提供闪电贷功能，允许借出代币并在同一交易内偿还
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override lock noDelegateCall {
        // 确保池中有流动性
        uint128 _liquidity = liquidity;
        require(_liquidity > 0, 'L');

        // 计算闪电贷费用
        uint256 fee0 = FullMath.mulDivRoundingUp(amount0, fee, 1e6);
        uint256 fee1 = FullMath.mulDivRoundingUp(amount1, fee, 1e6);
        
        // 记录初始余额
        uint256 balance0Before = balance0();
        uint256 balance1Before = balance1();

        // 转出请求的资金
        if (amount0 > 0) TransferHelper.safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) TransferHelper.safeTransfer(token1, recipient, amount1);

        // 调用回调，让调用者处理闪电贷逻辑并偿还+费用
        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(fee0, fee1, data);

        // 检查资金是否已偿还
        uint256 balance0After = balance0();
        uint256 balance1After = balance1();

        require(balance0Before.add(fee0) <= balance0After, 'F0');
        require(balance1Before.add(fee1) <= balance1After, 'F1');

        // 计算实际支付的费用
        // sub is safe because we know balanceAfter is gt balanceBefore by at least fee
        uint256 paid0 = balance0After - balance0Before;
        uint256 paid1 = balance1After - balance1Before;

        // 更新全局费用和协议费用
        if (paid0 > 0) {
            uint8 feeProtocol0 = slot0.feeProtocol % 16;
            uint256 fees0 = feeProtocol0 == 0 ? 0 : paid0 / feeProtocol0;
            if (uint128(fees0) > 0) protocolFees.token0 += uint128(fees0);
            feeGrowthGlobal0X128 += FullMath.mulDiv(paid0 - fees0, FixedPoint128.Q128, _liquidity);
        }
        if (paid1 > 0) {
            uint8 feeProtocol1 = slot0.feeProtocol >> 4;
            uint256 fees1 = feeProtocol1 == 0 ? 0 : paid1 / feeProtocol1;
            if (uint128(fees1) > 0) protocolFees.token1 += uint128(fees1);
            feeGrowthGlobal1X128 += FullMath.mulDiv(paid1 - fees1, FixedPoint128.Q128, _liquidity);
        }

        emit Flash(msg.sender, recipient, amount0, amount1, paid0, paid1);
    }

    /// @inheritdoc IUniswapV3PoolOwnerActions
    // 设置协议费用比例，只能由工厂所有者调用
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external override lock onlyFactoryOwner {
        // 验证费率有效性
        require(
            (feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
                (feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10))
        );
        uint8 feeProtocolOld = slot0.feeProtocol;
        slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4);
        emit SetFeeProtocol(feeProtocolOld % 16, feeProtocolOld >> 4, feeProtocol0, feeProtocol1);
    }

    /// @inheritdoc IUniswapV3PoolOwnerActions
    // 收集累积的协议费用，同样只能由工厂所有者调用
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external override lock onlyFactoryOwner returns (uint128 amount0, uint128 amount1) {
        // 计算实际可收集的协议费用
        amount0 = amount0Requested > protocolFees.token0 ? protocolFees.token0 : amount0Requested;
        amount1 = amount1Requested > protocolFees.token1 ? protocolFees.token1 : amount1Requested;

        // 更新协议费用状态并转账
        if (amount0 > 0) {
            if (amount0 == protocolFees.token0) amount0--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token0 -= amount0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            if (amount1 == protocolFees.token1) amount1--; // ensure that the slot is not cleared, for gas savings
            protocolFees.token1 -= amount1;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }

        emit CollectProtocol(msg.sender, recipient, amount0, amount1);
    }
}
