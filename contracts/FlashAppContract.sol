// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "./interfaces/IFlashReceiver.sol";

import "./libraries/SafeMath.sol";
import "./libraries/Address.sol";

import "./libraries/Create2.sol";

import "./pool/contracts/Pool.sol";
import "./interfaces/IFlashReceiver.sol";

import "./pool/interfaces/IERC20.sol";

contract FlashstakeProtocol is IFlashReceiver {
    using SafeMath for uint256;

    address
        public constant FLASH_CONTRACT = 0x419ba4EE0152b2e8c00CDdC2c22cf5b86667F6b7;

    address public FLASH_PROTOCOL = 0x9B5C5499d22dCB7F4FEbEC4159349095D8E4156E;

    mapping(bytes32 => uint256) public stakerReward;
    mapping(address => address) public pools; //Token -> pools

    event PoolCreated(address _pool, address _token);

    event LiquidityAdded(
        address _pool,
        address _token,
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _liquidity,
        uint256 _initiationTimestamp,
        address _sender
    );

    event LiquidityRemoved(
        address _pool,
        address _token,
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _liquidity,
        uint256 _initiationTimestamp,
        address _sender
    );

    event Staked(bytes32 _id, uint256 _rewardAmount);

    event Swapped(
        address _sender,
        uint256 _swapAmount,
        uint256 _flashReceived,
        uint256 _initiationTimestamp,
        address _pair
    );

    modifier onlyProtocol() {
        require(msg.sender == FLASH_PROTOCOL);
        _;
    }

    function createPool(address _token) external returns (address poolAddress) {
        require(
            _token != address(0),
            "Flashapp_contract:: INVALID_TOKEN_ADDRESS"
        );
        require(
            pools[_token] == address(0),
            "PFlashapp_contract:: POOL_ALREADY_EXISTS"
        );
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        poolAddress = Create2.deploy(0, salt, bytecode);
        pools[_token] = poolAddress;
        IPool(poolAddress).initialize(FLASH_CONTRACT, _token);
        emit PoolCreated(poolAddress, _token);
    }

    function receiveFlash(
        bytes32 _id,
        uint256 _amountIn,
        uint256 _expireAfter,
        uint256 _mintedAmount,
        address _staker,
        bytes calldata _data
    ) external onlyProtocol returns (uint256) {
        (address token, address staker, uint256 expectedOutput) = abi.decode(
            _data,
            (address, address, uint256)
        );
        address pool = pools[token];

        IERC20(FLASH_TOKEN).transfer(pool, _mintedAmount);

        reward = distributeStakeReward(_minted, pool, staker, _expectedOutput);

        stakerReward[_id] = reward;

        emit Staked(_id, reward);
    }

    function distributeStakeReward(
        uint256 _flashQuantity,
        address _pool,
        address _staker,
        uint256 _expectedOutput
    ) internal returns (uint256 result) {
        result = IPool(_pool).stakeWithFeeRewardDistribution(
            _flashQuantity,
            _staker,
            _expectedOutput
        );
    }

    function unstake(bytes32[] memory _expiredIds)
        public
        returns (uint256 withdrawAmount)
    {
        withdrawAmount = 0;
        for (uint256 i = 0; i < _expiredIds.length; i = i.add(1)) {
            IFlashProtocol(FLASH_PROTOCOL).unstake(
                _expiredIds[i],
                stakerData[_expiredIds[i]].flashQuantity
            );
        }
    }

    function swap(
        uint256 _altQuantity,
        address _token,
        uint256 _expectedOutput
    ) public returns (uint256 result) {
        require(_altQuantity > 0, "Flashapp_contract:: INVALID_AMOUNT");
        require(
            pools[_token] != address(0),
            "Flashapp_contract:: POOL_DOESNT_EXIST"
        );

        IERC20(_token).transferFrom(msg.sender, address(this), _altQuantity);
        IERC20(_token).transfer(pools[_token], _altQuantity);

        result = IPool(pools[_token]).swapWithFeeRewardDistribution(
            _altQuantity,
            msg.sender,
            _expectedOutput
        );

        emit Swapped(
            msg.sender,
            _altQuantity,
            result,
            block.timestamp,
            pools[_token]
        );
    }

    function addLiquidityInPool(
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _amountFLASHMin,
        uint256 _amountALTMin,
        address _token
    ) public {
        address pool = pools[_token];
        address maker = msg.sender;
        require(pool != address(0), "Flashapp_contract:: POOL_DOESNT_EXIST");
        require(
            _amountFLASH > 0 && _amountALT > 0,
            "Flashapp_contract:: INVALID_AMOUNT"
        );

        (uint256 amountFLASH, uint256 amountALT, uint256 liquidity) = IPool(
            pool
        )
            .addLiquidity(
            _amountFLASH,
            _amountALT,
            _amountFLASHMin,
            _amountALTMin,
            maker
        );

        IERC20(FLASH_CONTRACT).transferFrom(maker, address(this), amountFLASH);
        IERC20(FLASH_CONTRACT).transfer(pool, amountFLASH);
        IERC20(_token).transferFrom(maker, address(this), amountALT);
        IERC20(_token).transfer(pool, amountALT);

        emit LiquidityAdded(
            pools,
            _token,
            amountFLASH,
            amountALT,
            liquidity,
            block.timestamp,
            maker
        );
    }

    function removeLiquidityInPool(uint256 _liquidity, address _token) public {
        address pool = pools[_token];
        require(pool != address(0), "Flashapp_contract:: POOL_DOESNT_EXIST");

        IERC20(pool).transferFrom(msg.sender, pool, _liquidity);

        (uint256 amountFLASH, uint256 amountALT) = IPool(pools[_token])
            .removeLiquidity(_liquidity, msg.sender);

        emit LiquidityRemoved(
            pools[_token],
            _token,
            amountFLASH,
            amountALT,
            _liquidity,
            block.timestamp,
            msg.sender
        );
    }
}
