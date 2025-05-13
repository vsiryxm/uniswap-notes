// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0 <0.8.0;

/// @title 包含512位数学函数
/// @notice 支持可能出现中间值溢出的乘法和除法运算，但不会丢失精度
/// @dev 处理"幻影溢出"，即允许乘法和除法，其中中间值可能超出256位，但不会影响精度
library FullMath {
    /// @notice 使用完整精度计算 floor(a×b÷denominator)。如果结果溢出uint256或除数为0，则抛出异常
    /// @param a 被乘数
    /// @param b 乘数
    /// @param denominator 除数
    /// @return result 计算结果（256位）
    /// @dev 感谢Remco Bloemen，MIT许可证 https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512位乘法 [prod1 prod0] = a * b
        // 计算对2**256和2**256-1取模的乘积
        // 然后使用中国剩余定理重构512位结果
        // 结果存储在两个256位变量中，满足product = prod1 * 2**256 + prod0
        uint256 prod0; // 乘积的低256位
        uint256 prod1; // 乘积的高256位
        assembly {
            let mm := mulmod(a, b, not(0))
            prod0 := mul(a, b)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // 处理无溢出情况，256位除以256位的除法
        if (prod1 == 0) {
            require(denominator > 0);
            assembly {
                result := div(prod0, denominator)
            }
            return result;
        }

        // 确保结果小于2**256
        // 同时防止除数为0
        require(denominator > prod1);

        ///////////////////////////////////////////////
        // 512位除以256位的除法
        ///////////////////////////////////////////////

        // 通过减去余数使除法精确
        // 使用mulmod计算余数
        uint256 remainder;
        assembly {
            remainder := mulmod(a, b, denominator)
        }
        // 从512位数中减去256位数
        assembly {
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // 从除数中分解2的幂因子
        // 计算除数的最大2的幂因子
        // 始终 >= 1
        uint256 twos = -denominator & denominator;
        // 将除数除以2的幂
        assembly {
            denominator := div(denominator, twos)
        }

        // 将[prod1 prod0]除以2的因子
        assembly {
            prod0 := div(prod0, twos)
        }
        // 将prod1的位移入prod0
        // 为此，我们需要翻转`twos`使其成为2**256 / twos
        // 如果twos为零，则变为1
        assembly {
            twos := add(div(sub(0, twos), twos), 1)
        }
        prod0 |= prod1 * twos;

        // 计算除数在模2**256下的逆元
        // 现在除数是奇数，它在模2**256下有逆元
        // 使得 denominator * inv = 1 mod 2**256
        // 从正确的4位种子开始计算逆元
        // 即 denominator * inv = 1 mod 2**4
        uint256 inv = (3 * denominator) ^ 2;
        // 使用牛顿-拉弗森迭代法提高精度
        // 由于Hensel引理，这在模运算中也有效
        // 每一步都使正确位数加倍
        inv *= 2 - denominator * inv; // 模2**8的逆元
        inv *= 2 - denominator * inv; // 模2**16的逆元
        inv *= 2 - denominator * inv; // 模2**32的逆元
        inv *= 2 - denominator * inv; // 模2**64的逆元
        inv *= 2 - denominator * inv; // 模2**128的逆元
        inv *= 2 - denominator * inv; // 模2**256的逆元

        // 因为除法现在是精确的，我们可以通过乘以除数的模逆元来进行除法
        // 这将给我们模2**256的正确结果
        // 由于前提条件保证结果小于2**256，这就是最终结果
        // 我们不需要计算结果的高位，prod1不再需要
        result = prod0 * inv;
        return result;
    }

    /// @notice 使用完整精度计算 ceil(a×b÷denominator)。如果结果溢出uint256或除数为0，则抛出异常
    /// @param a 被乘数
    /// @param b 乘数
    /// @param denominator 除数
    /// @return result 计算结果（256位）
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        result = mulDiv(a, b, denominator);
        if (mulmod(a, b, denominator) > 0) {
            require(result < type(uint256).max);
            result++;
        }
    }
}
