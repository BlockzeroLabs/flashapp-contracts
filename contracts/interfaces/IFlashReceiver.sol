// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IFlashReceiver {
    function receiveFlash(
        bytes32 _id,
        uint256 _amountIn,
        uint256 _expireAfter,
        uint256 _mintedAmount,
        address _staker,
        bytes calldata _data
    ) external returns (uint256);
}
