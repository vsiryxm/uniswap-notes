// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library TransferHelper {
    /// @notice 将代币从目标地址转移到给定目的地
    /// @notice 如果转账失败则返回错误'STF'
    /// @param token 要转移的代币的合约地址
    /// @param from 代币将从其转出的源地址
    /// @param to 转账的目标地址
    /// @param value 要转移的金额
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    /// @notice 将代币从msg.sender转移到接收者
    /// @dev 如果转账失败则返回错误'ST'
    /// @param token 将被转移的代币的合约地址
    /// @param to 转账的接收者
    /// @param value 转账的金额
    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    /// @notice 批准指定合约花费给定代币中的给定限额
    /// @dev 如果批准失败则返回错误'SA'
    /// @param token 要被批准的代币的合约地址
    /// @param to 批准的目标
    /// @param value 目标将被允许花费的给定代币的金额
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    /// @notice 将ETH转移到接收者地址
    /// @dev 失败时返回错误'STE'
    /// @param to 转账的目的地
    /// @param value 要转移的金额
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}
