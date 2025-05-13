// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

import './FullMath.sol';
import './FixedPoint128.sol';
import './LiquidityMath.sol';

/// @title 头寸
/// @notice 头寸代表所有者地址在下限和上限tick边界之间的流动性
/// @dev 头寸存储额外状态以跟踪欠头寸的费用
library Position {
    // 为每个用户的头寸存储的信息
    struct Info {
        // 此头寸拥有的流动性数量
        uint128 liquidity;
        // 上次更新流动性或欠款费用时的每单位流动性费用增长
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // 欠头寸所有者的token0/token1费用
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    /// @notice 返回给定所有者和头寸边界的Info结构
    /// @param self 包含所有用户头寸的映射
    /// @param owner 头寸所有者的地址
    /// @param tickLower 头寸的下限tick边界
    /// @param tickUpper 头寸的上限tick边界
    /// @return position 给定所有者头寸的位置信息结构
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /// @notice 将累积费用记入用户头寸
    /// @param self 要更新的个人头寸
    /// @param liquidityDelta 由于头寸更新导致的池流动性变化
    /// @param feeGrowthInside0X128 头寸tick边界内token0的全时间费用增长，每单位流动性
    /// @param feeGrowthInside1X128 头寸tick边界内token1的全时间费用增长，每单位流动性
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, 'NP'); // 禁止为流动性为0的头寸进行戳动（poke）
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
        }

        // 计算累积费用
        uint128 tokensOwed0 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 tokensOwed1 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );

        // 更新头寸
        if (liquidityDelta != 0) self.liquidity = liquidityNext;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            // 溢出是可接受的，必须在达到type(uint128).max费用之前提款
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }
}
