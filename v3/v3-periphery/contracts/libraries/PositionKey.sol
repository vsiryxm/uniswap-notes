// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

library PositionKey {
    /// @dev 返回核心库中头寸的密钥
    function compute(
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    }
}