// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.8;

interface IPool {
    function initialize(address _xioAddress, address _token) external;

    function stakeWithFeeRewardDistribution(
        uint256 _amountIn,
        address _staker,
        uint256 _expectedOutput
    ) external returns (uint256 result);

    function addLiquidity(
        uint256 _amountXIO,
        uint256 _amountALT,
        uint256 _amountXIOMin,
        uint256 _amountALTMin,
        address _maker
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function removeLiquidity(uint256 liquidity,address _maker) external returns (uint256, uint256);

    function swapWithFeeRewardDistribution(
        uint256 _amountIn,
        address _staker,
        uint256 _expectedOutput
    ) external returns (uint256 result);
}
