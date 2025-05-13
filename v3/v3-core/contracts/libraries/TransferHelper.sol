// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '../interfaces/IERC20Minimal.sol';

/// @title 转账助手
/// @notice 包含与不一致返回true/false的ERC20代币交互的辅助方法
library TransferHelper {
    /// @notice 将代币从msg.sender转移给接收者
    /// @dev 调用代币合约的transfer方法，如果转账失败则返回错误TF
    /// @param token 将被转移的代币合约地址
    /// @param to 转账的接收者
    /// @param value 转账的金额
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TF');
    }
}
