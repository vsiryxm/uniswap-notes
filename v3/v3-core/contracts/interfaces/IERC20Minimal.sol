// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Uniswap的最小ERC20接口
/// @notice 包含在Uniswap V3中使用的完整ERC20接口的子集
interface IERC20Minimal {
    /// @notice 返回代币余额
    /// @param account 要查询其代币数量（即余额）的账户
    /// @return 账户持有的代币数量
    function balanceOf(address account) external view returns (uint256);

    /// @notice 将代币数量从`msg.sender`转移给接收者
    /// @param recipient 将接收转移金额的账户
    /// @param amount 从发送者发送给接收者的代币数量
    /// @return 成功转移返回true，失败转移返回false
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice 返回所有者给予支出者的当前授权额
    /// @param owner 代币所有者的账户
    /// @param spender 代币支出者的账户
    /// @return `owner`给予`spender`的当前授权额
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice 将`msg.sender`给予支出者的授权额设置为`amount`
    /// @param spender 将被允许使用所有者代币一定数量的账户
    /// @param amount `spender`被允许使用的代币数量
    /// @return 成功授权返回true，失败授权返回false
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice 从`sender`向`recipient`转移`amount`数量的代币，最多不超过给予`msg.sender`的授权额
    /// @param sender 将启动转移的账户
    /// @param recipient 转移的接收者
    /// @param amount 转移的数量
    /// @return 成功转移返回true，失败转移返回false
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /// @notice 当代币从一个地址转移到另一个地址时发出的事件，通过`#transfer`或`#transferFrom`。
    /// @param from 发送代币的账户，即余额减少
    /// @param to 接收代币的账户，即余额增加
    /// @param value 被转移的代币数量
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice 当特定所有者代币的支出者授权额变化时发出的事件。
    /// @param owner 批准其代币支出的账户
    /// @param spender 支出授权被修改的账户
    /// @param value 所有者给予支出者的新授权额
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
