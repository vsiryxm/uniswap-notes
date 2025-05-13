// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

/// @title 防止对合约进行delegatecall
/// @notice 提供一个修饰符，用于防止对子合约中的方法进行delegatecall
abstract contract NoDelegateCall {
    /// @dev 该合约的原始地址
    address private immutable original;

    constructor() {
        // immutable变量在合约的初始化代码中计算，然后内联到部署的字节码中。
        // 换句话说，当在运行时检查这个变量时，它不会改变。
        original = address(this);
    }

    /// @dev 使用私有方法而不是直接内联到修饰符中，因为修饰符会被复制到每个使用它的方法中，
    ///     而immutable的使用意味着在每个使用修饰符的地方都会复制地址字节。
    function checkNotDelegateCall() private view {
        require(address(this) == original);
    }

    /// @notice 防止对修饰的方法进行delegatecall
    modifier noDelegateCall() {
        checkNotDelegateCall();
        _;
    }
}