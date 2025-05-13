# Uniswap V3 学习计划：专注于询价和预言机原理

## 第1天：Uniswap V3 基础概念和架构

**目标**：了解 Uniswap V3 的整体架构、核心概念和 v3-core 与 v3-periphery 的关系

**学习内容**：
1. 阅读并理解 README.md 和 README.md
2. 熟悉集中流动性、价格范围、tick 的概念
3. 了解 Uniswap V3 中的费用结构
4. 探索 v3-core 和 v3-periphery 的项目结构

**关键文件**：
- README.md
- README.md
- UniswapV3Factory.sol
- UniswapV3Pool.sol（初步概览）

## 第2天：价格表示和 Tick 机制

**目标**：理解 Uniswap V3 中的价格表示方法和 Tick 系统，这是询价机制的基础

**学习内容**：
1. Uniswap 中的价格表示（√P）
2. Tick 的概念及其与价格的关系
3. Tick 间距和费用层级的关系
4. Tick Math 的实现

**关键文件**：
- TickMath.sol
- SqrtPriceMath.sol
- FullMath.sol
- FixedPoint96.sol

## 第3天：Pool 合约和状态管理

**目标**：深入理解 Pool 合约的状态管理和交易机制，这是询价系统的核心

**学习内容**：
1. Pool 的初始化和状态变量
2. Slot0 数据结构（包含当前价格和 tick）
3. 流动性管理（mint, burn）
4. 交易实现（swap）

**关键文件**：
- UniswapV3Pool.sol（深入分析）
- Position.sol
- Tick.sol

## 第4天：预言机机制 - 核心实现

**目标**：专注于 Uniswap V3 的预言机实现机制

**学习内容**：
1. 累积价格和时间加权平均价格（TWAP）
2. Oracle 的数据结构和存储
3. 预言机的历史数据管理
4. 观察数据的读取和计算

**关键文件**：
- Oracle.sol
- UniswapV3Pool.sol 中的 oracle 相关方法
- Oracle.spec.ts（理解测试用例有助于理解实现）

## 第5天：询价机制 - 中间层接口

**目标**：学习 v3-periphery 中的询价接口和封装

**学习内容**：
1. 价格查询接口
2. 外部查询合约
3. 时间加权平均价格（TWAP）的计算
4. 价格范围的管理

**关键文件**：
- OracleLibrary.sol
- `v3-periphery/contracts/interfaces/IUniswapV3Pool.sol`
- Quoter.sol
- QuoterV2.sol

## 第6天：深入 Swap 和 Quoter 实现

**目标**：理解 Swap 过程中的价格计算和 Quoter 合约的实现

**学习内容**：
1. Swap 过程中的价格计算
2. Quoter 合约如何查询交易结果
3. 路径处理和多跳交易
4. 滑点保护机制

**关键文件**：
- SwapMath.sol
- SwapRouter.sol
- Quoter.sol（深入分析）
- QuoterV2.sol（深入分析）
- PeripheryImmutableState.sol

## 第7天：高级主题和综合理解

**目标**：综合所学知识，解决实际问题，加深对询价和预言机的理解

**学习内容**：
1. 测试用例分析 - 理解询价测试
2. 预言机攻击和防御机制
3. 价格操纵的风险
4. 观察测试中的边界条件和极端情况

**关键文件**：
- UniswapV3Pool.spec.ts
- Quoter.spec.ts
- OracleLibrary.spec.ts
- Oracle.spec.ts（深入分析）

## 实用学习建议

1. **逐行注释**：按照计划的顺序逐个文件阅读并添加中文注释
2. **连接概念**：将不同文件中的相关概念相互连接
3. **测试用例**：通过测试用例理解代码的实际行为
4. **画图**：绘制流程图或状态图帮助理解复杂机制
5. **实际尝试**：如果可能，在测试网上与合约交互以加深理解

## 重点概念解释

- **√P**: Uniswap V3 使用平方根价格表示法，这有助于计算效率
- **Tick**: 离散化的价格点，用于定义价格范围
- **Oracle**: Uniswap V3 的预言机通过累积历史价格数据提供 TWAP
- **Quoter**: 预估交易结果而不实际执行交易的合约
- **TWAP**: 时间加权平均价格，Uniswap 预言机的核心机制
