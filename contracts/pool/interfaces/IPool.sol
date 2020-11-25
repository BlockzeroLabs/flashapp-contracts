// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IPool {
    function initialize(address _token) external;

    function stakeWithFeeRewardDistribution(
        uint256 _amountIn,
        address _staker,
        uint256 _expectedOutput
    ) external returns (uint256 result);

    function addLiquidity(
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _amountFLASHMin,
        uint256 _amountALTMin,
        address _maker
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        );

    function removeLiquidity(address _maker) external returns (uint256, uint256);

    function swapWithFeeRewardDistribution(
        uint256 _amountIn,
        address _staker,
        uint256 _expectedOutput
    ) external returns (uint256 result);
}
