// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "./interfaces/IERC20.sol";
import "./interfaces/IFlashReceiver.sol";
import "./interfaces/IFlashReceiver.sol";
import "./interfaces/IFlashProtocol.sol";

import "./libraries/SafeMath.sol";
import "./libraries/Address.sol";
import "./libraries/Create2.sol";

import "./pool/contracts/Pool.sol";

contract FlashstakeProtocol is IFlashReceiver {
    using SafeMath for uint256;

    address public constant FLASH_TOKEN = address(0);
    address public constant FLASH_PROTOCOL = address(0);

    mapping(bytes32 => uint256) public stakerReward;
    mapping(address => address) public pools; // token -> pools

    event PoolCreated(address _pool, address _token);

    event Staked(bytes32 _id, uint256 _rewardAmount);

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

    event Swapped(
        address _sender,
        uint256 _swapAmount,
        uint256 _flashReceived,
        uint256 _initiationTimestamp,
        address _pair
    );

    modifier onlyProtocol() {
        require(msg.sender == FLASH_PROTOCOL, "FlashApp:: ONLY_PROTOCOL");
        _;
    }

    function createPool(address _token) external returns (address poolAddress) {
        require(_token != address(0), "FlashApp:: INVALID_TOKEN_ADDRESS");
        require(pools[_token] == address(0), "FlashApp:: POOL_ALREADY_EXISTS");
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        poolAddress = Create2.deploy(0, salt, bytecode);
        pools[_token] = poolAddress;
        IPool(poolAddress).initialize(_token);
        emit PoolCreated(poolAddress, _token);
    }

    function receiveFlash(
        bytes32 _id,
        uint256 _amountIn, //unused
        uint256 _expireAfter, //unused
        uint256 _mintedAmount,
        address _staker, //unused
        bytes calldata _data
    ) external override onlyProtocol returns (uint256) {
        (address token, address staker, uint256 expectedOutput) = abi.decode(_data, (address, address, uint256));
        address pool = pools[token];
        IERC20(FLASH_TOKEN).transfer(pool, _mintedAmount);
        uint256 reward = IPool(pool).stakeWithFeeRewardDistribution(_mintedAmount, staker, expectedOutput);
        stakerReward[_id] = reward;
        emit Staked(_id, reward);
    }

    function unstake(bytes32[] memory _expiredIds) public {
        for (uint256 i = 0; i < _expiredIds.length; i = i.add(1)) {
            IFlashProtocol(FLASH_PROTOCOL).unstake(_expiredIds[i]);
        }
    }

    function swap(
        uint256 _altQuantity,
        address _token,
        uint256 _expectedOutput
    ) public returns (uint256 result) {
        address user = msg.sender;
        address pool = pools[_token];

        require(pool != address(0), "FlashApp:: POOL_DOESNT_EXIST");
        require(_altQuantity > 0, "FlashApp:: INVALID_AMOUNT");

        IERC20(_token).transferFrom(user, address(this), _altQuantity);
        IERC20(_token).transfer(pool, _altQuantity);

        result = IPool(pool).swapWithFeeRewardDistribution(_altQuantity, user, _expectedOutput);

        emit Swapped(user, _altQuantity, result, block.timestamp, pool);
    }

    function addLiquidityInPool(
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _amountFLASHMin,
        uint256 _amountALTMin,
        address _token
    ) public {
        address maker = msg.sender;
        address pool = pools[_token];

        require(pool != address(0), "FlashApp:: POOL_DOESNT_EXIST");
        require(_amountFLASH > 0 && _amountALT > 0, "FlashApp:: INVALID_AMOUNT");

        (uint256 amountFLASH, uint256 amountALT, uint256 liquidity) = IPool(pool).addLiquidity(
            _amountFLASH,
            _amountALT,
            _amountFLASHMin,
            _amountALTMin,
            maker
        );

        IERC20(FLASH_TOKEN).transferFrom(maker, address(this), amountFLASH);
        IERC20(FLASH_TOKEN).transfer(pool, amountFLASH);
        IERC20(_token).transferFrom(maker, address(this), amountALT);
        IERC20(_token).transfer(pool, amountALT);

        emit LiquidityAdded(pool, _token, amountFLASH, amountALT, liquidity, block.timestamp, maker);
    }

    function removeLiquidityInPool(uint256 _liquidity, address _token) public {
        address pool = pools[_token];

        require(pool != address(0), "FlashApp:: POOL_DOESNT_EXIST");

        IERC20(pool).transferFrom(msg.sender, pool, _liquidity);

        (uint256 amountFLASH, uint256 amountALT) = IPool(pool).removeLiquidity(msg.sender);

        emit LiquidityRemoved(pool, _token, amountFLASH, amountALT, _liquidity, block.timestamp, msg.sender);
    }
}
