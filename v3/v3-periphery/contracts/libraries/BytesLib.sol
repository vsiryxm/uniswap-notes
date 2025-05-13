// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * @title Solidity字节数组工具
 * @author Gonçalo Sá <goncalo.sa@consensys.net>
 *
 * @dev 以太坊合约用的紧密打包的字节数组工具库，用Solidity编写。
 *      该库允许你在内存和存储中连接、切片和类型转换字节数组。
 */
pragma solidity >=0.5.0 <0.8.0;

library BytesLib {
    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    ) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, 'slice_overflow');
        require(_start + _length >= _start, 'slice_overflow');
        require(_bytes.length >= _start + _length, 'slice_outOfBounds');

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
                case 0 {
                    // 获取一些空闲内存的位置并将其存储在tempBytes中，
                    // 就像Solidity为内存变量所做的那样。
                    tempBytes := mload(0x40)

                    // 切片结果的第一个字可能是从原始数组读取的部分字。
                    // 为了读取它，我们计算该部分字的长度，
                    // 并开始将那么多字节复制到数组中。
                    // 我们复制的第一个字将以我们不关心的数据开始，
                    // 但最后的`lengthmod`字节将落在新数组内容的开头。
                    // 当我们完成复制后，我们用切片的实际长度覆盖整个第一个字。
                    let lengthmod := and(_length, 31)

                    // 下一行的乘法是必要的，
                    // 因为当切片32字节的倍数（lengthmod == 0）时，
                    // 下面的复制循环会复制源的长度，然后过早地结束，
                    // 没有复制它应该复制的全部内容。
                    let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                    let end := add(mc, _length)

                    for {
                        // 下一行的乘法与上面的乘法具有完全相同的目的。
                        let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                    } lt(mc, end) {
                        mc := add(mc, 0x20)
                        cc := add(cc, 0x20)
                    } {
                        mstore(mc, mload(cc))
                    }

                    mstore(tempBytes, _length)

                    //更新空闲内存指针
                    //像编译器现在那样分配填充到32字节的数组
                    mstore(0x40, and(add(mc, 31), not(31)))
                }
                //如果我们想要一个零长度切片，就只返回一个零长度数组
                default {
                    tempBytes := mload(0x40)
                    //将我们要返回的32字节切片清零
                    //我们需要这样做，因为Solidity不进行垃圾收集
                    mstore(tempBytes, 0)

                    mstore(0x40, add(tempBytes, 0x20))
                }
        }

        return tempBytes;
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        require(_start + 20 >= _start, 'toAddress_overflow');
        require(_bytes.length >= _start + 20, 'toAddress_outOfBounds');
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint24(bytes memory _bytes, uint256 _start) internal pure returns (uint24) {
        require(_start + 3 >= _start, 'toUint24_overflow');
        require(_bytes.length >= _start + 3, 'toUint24_outOfBounds');
        uint24 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x3), _start))
        }

        return tempUint;
    }
}
