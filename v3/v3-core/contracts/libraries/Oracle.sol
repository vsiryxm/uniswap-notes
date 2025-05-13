// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

/// @title 预言机库
/// @notice 提供对各种系统设计有用的价格和流动性数据
/// @dev 存储的预言机数据实例"观察值"被收集在预言机数组中
/// 每个池初始化时预言机数组长度为1。任何人都可以支付SSTORE费用来增加预言机数组的最大长度。
/// 当数组完全填充时，会添加新的存储槽。当预言机数组的完整长度被填满时，观察值会被覆盖。
/// 最近的观察值可以通过向observe()传递0来获取，这与预言机数组的长度无关。
library Oracle {
    struct Observation {
        // 观察的区块时间戳
        uint32 blockTimestamp;
        // tick累加器，即自池初始化以来的tick * 经过时间
        int56 tickCumulative;
        // 每单位流动性的秒数，即自池初始化以来的经过秒数 / max(1, liquidity)
        uint160 secondsPerLiquidityCumulativeX128;
        // 观察是否已初始化
        bool initialized;
    }

    /// @notice 根据时间流逝和当前tick和流动性值，将先前的观察值转换为新的观察值
    /// @dev blockTimestamp _必须_ 在时间上等于或大于last.blockTimestamp，对0或1次溢出安全
    /// @param last 要转换的指定观察值
    /// @param blockTimestamp 新观察值的时间戳
    /// @param tick 新观察时的当前tick
    /// @param liquidity 新观察时的总在范围内流动性
    /// @return Observation 新填充的观察值
    function transform(
        Observation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) private pure returns (Observation memory) {
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * delta,
                secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)),
                initialized: true
            });
    }

    /// @notice 通过写入第一个槽初始化预言机数组。在观察数组的生命周期中只调用一次
    /// @param self 存储的预言机数组
    /// @param time 通过截断为uint32的block.timestamp获取的预言机初始化时间
    /// @return cardinality 预言机数组中已填充元素的数量
    /// @return cardinalityNext 预言机数组的新长度，与填充情况无关
    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = Observation({
            blockTimestamp: time,
            tickCumulative: 0,
            secondsPerLiquidityCumulativeX128: 0,
            initialized: true
        });
        return (1, 1);
    }

    /// @notice 将预言机观察值写入数组
    /// @dev 每个区块最多可写入一次。index表示最近写入的元素。cardinality和index必须在外部跟踪。
    /// 如果索引在允许的数组长度末尾（根据cardinality），并且下一个cardinality大于当前cardinality，
    /// 则可以增加cardinality。这个限制是为了保持顺序。
    /// @param self 存储的预言机数组
    /// @param index 最近写入观察数组的观察索引
    /// @param blockTimestamp 新观察的时间戳
    /// @param tick 新观察时的当前tick
    /// @param liquidity 新观察时的总在范围内流动性
    /// @param cardinality 预言机数组中已填充元素的数量
    /// @param cardinalityNext 预言机数组的新长度，与填充情况无关
    /// @return indexUpdated 预言机数组中最近写入元素的新索引
    /// @return cardinalityUpdated 预言机数组的新基数
    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];

        // 如果我们在这个区块已经写了一个观察值，提前返回
        if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

        // 如果条件合适，我们可以增加基数
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, blockTimestamp, tick, liquidity);
    }

    /// @notice 准备预言机数组存储最多`next`个观察值
    /// @param self 存储的预言机数组
    /// @param current 预言机数组当前的下一个基数
    /// @param next 将在预言机数组中填充的建议下一个基数
    /// @return next 将在预言机数组中填充的下一个基数
    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        require(current > 0, 'I');
        // 如果传入的next值不大于当前next值，则不操作
        if (next <= current) return current;
        // 在每个槽中存储以防止在交换中新的SSTORE操作
        // 这些数据不会被使用，因为initialized布尔值仍为false
        for (uint16 i = current; i < next; i++) self[i].blockTimestamp = 1;
        return next;
    }

    /// @notice 32位时间戳的比较器
    /// @dev 对0或1次溢出安全，a和b _必须_ 在时间上早于或等于time
    /// @param time 截断为32位的时间戳
    /// @param a 用于确定`time`相对位置的比较时间戳
    /// @param b 用于确定`time`相对位置的另一个比较时间戳
    /// @return bool `a`是否在时间上 <= `b`
    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // 如果没有溢出，不需要调整
        if (a <= time && b <= time) return a <= b;

        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }

    /// @notice 获取目标时间之前和之后的观察值，即满足[beforeOrAt, atOrAfter]条件的观察值。
    /// 结果可能是相同的观察值，或相邻的观察值。
    /// @dev 答案必须包含在数组中，在目标位于存储的观察边界内时使用：比最近的观察值更早，或与最旧的观察值相同或更年轻
    /// @param self 存储的预言机数组
    /// @param time 当前block.timestamp
    /// @param target 预留观察应该为之准备的时间戳
    /// @param index 最近写入观察数组的观察索引
    /// @param cardinality 预言机数组中已填充元素的数量
    /// @return beforeOrAt 在目标时间或之前记录的观察值
    /// @return atOrAfter 在目标时间或之后记录的观察值
    function binarySearch(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        uint256 l = (index + 1) % cardinality; // 最旧的观察值
        uint256 r = l + cardinality - 1; // 最新的观察值
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % cardinality];

            // 我们找到了一个未初始化的tick，继续向上搜索（更近期）
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }

            atOrAfter = self[(i + 1) % cardinality];

            bool targetAtOrAfter = lte(time, beforeOrAt.blockTimestamp, target);

            // 检查是否找到了答案！
            if (targetAtOrAfter && lte(time, target, atOrAfter.blockTimestamp)) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    /// @notice 获取目标时间之前和之后的观察值，即满足[beforeOrAt, atOrAfter]条件的观察值
    /// @dev 假定至少有1个已初始化的观察值。
    /// 由observeSingle()用于计算给定区块时间戳的反事实累加器值。
    /// @param self 存储的预言机数组
    /// @param time 当前block.timestamp
    /// @param target 预留观察应该为之准备的时间戳
    /// @param tick 返回或模拟观察时的当前tick
    /// @param index 最近写入观察数组的观察索引
    /// @param liquidity 调用时的总池流动性
    /// @param cardinality 预言机数组中已填充元素的数量
    /// @return beforeOrAt 发生在给定时间戳或之前的观察值
    /// @return atOrAfter 发生在给定时间戳或之后的观察值
    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        // 乐观地将beforeOrAt设置为最新观察值
        beforeOrAt = self[index];

        // 如果目标在时间上等于或晚于最新观察值，我们可以提前返回
        if (lte(time, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {
                // 如果最新观察值等于目标，我们处于同一区块，因此可以忽略atOrAfter
                return (beforeOrAt, atOrAfter);
            } else {
                // 否则，我们需要转换
                return (beforeOrAt, transform(beforeOrAt, target, tick, liquidity));
            }
        }

        // 现在，将beforeOrAt设置为最旧的观察值
        beforeOrAt = self[(index + 1) % cardinality];
        if (!beforeOrAt.initialized) beforeOrAt = self[0];

        // 确保目标在时间上等于或晚于最旧的观察值
        require(lte(time, beforeOrAt.blockTimestamp, target), 'OLD');

        // 如果我们到达这一点，我们必须使用二分查找
        return binarySearch(self, time, target, index, cardinality);
    }

    /// @dev 如果在所需观察时间戳或之前不存在观察值，则会回滚。
    /// 可以传递'0'作为`secondsAgo`返回当前累积值。
    /// 如果调用时间落在两个观察值之间，返回两个观察值之间的时间戳处的反事实累加器值。
    /// @param self 存储的预言机数组
    /// @param time 当前区块时间戳
    /// @param secondsAgo 要回溯的秒数，返回该时间点的观察值
    /// @param tick 当前tick
    /// @param index 最近写入观察数组的观察索引
    /// @param liquidity 当前在范围内的池流动性
    /// @param cardinality 预言机数组中已填充元素的数量
    /// @return tickCumulative 池首次初始化后的tick * 经过时间，截至`secondsAgo`
    /// @return secondsPerLiquidityCumulativeX128 池首次初始化后的经过时间 / max(1, liquidity)，截至`secondsAgo`
    function observeSingle(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) {
        if (secondsAgo == 0) {
            Observation memory last = self[index];
            if (last.blockTimestamp != time) last = transform(last, time, tick, liquidity);
            return (last.tickCumulative, last.secondsPerLiquidityCumulativeX128);
        }

        uint32 target = time - secondsAgo;

        (Observation memory beforeOrAt, Observation memory atOrAfter) =
            getSurroundingObservations(self, time, target, tick, index, liquidity, cardinality);

        if (target == beforeOrAt.blockTimestamp) {
            // 我们在左边界
            return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
        } else if (target == atOrAfter.blockTimestamp) {
            // 我们在右边界
            return (atOrAfter.tickCumulative, atOrAfter.secondsPerLiquidityCumulativeX128);
        } else {
            // 我们在中间
            uint32 observationTimeDelta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
            uint32 targetDelta = target - beforeOrAt.blockTimestamp;
            return (
                beforeOrAt.tickCumulative +
                    ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / observationTimeDelta) *
                    targetDelta,
                beforeOrAt.secondsPerLiquidityCumulativeX128 +
                    uint160(
                        (uint256(
                            atOrAfter.secondsPerLiquidityCumulativeX128 - beforeOrAt.secondsPerLiquidityCumulativeX128
                        ) * targetDelta) / observationTimeDelta
                    )
            );
        }
    }

    /// @notice 返回`secondsAgos`数组中每个时间点的累积值
    /// @dev 如果`secondsAgos` > 最旧的观察值，则会回滚
    /// @param self 存储的预言机数组
    /// @param time 当前block.timestamp
    /// @param secondsAgos 每个回溯的时间量（以秒为单位），在这个时间点返回观察值
    /// @param tick 当前tick
    /// @param index 最近写入观察数组的观察索引
    /// @param liquidity 当前在范围内的池流动性
    /// @param cardinality 预言机数组中已填充元素的数量
    /// @return tickCumulatives 池首次初始化后的tick * 经过时间，截至每个`secondsAgo`
    /// @return secondsPerLiquidityCumulativeX128s 池首次初始化后的累积秒数 / max(1, liquidity)，截至每个`secondsAgo`
    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        require(cardinality > 0, 'I');

        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            (tickCumulatives[i], secondsPerLiquidityCumulativeX128s[i]) = observeSingle(
                self,
                time,
                secondsAgos[i],
                tick,
                index,
                liquidity,
                cardinality
            );
        }
    }
}
