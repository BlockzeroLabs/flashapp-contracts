// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IERC20.sol";
import "./interfaces/IFlashToken.sol";
import "./interfaces/IFlashReceiver.sol";
import "./interfaces/IFlashReceiver.sol";
import "./interfaces/IFlashProtocol.sol";

import "./libraries/SafeMath.sol";
import "./libraries/Address.sol";
import "./libraries/Create2.sol";

import "./pool/contracts/Pool.sol";

contract FlashApp is IFlashReceiver {
    using SafeMath for uint256;

    address public constant FLASH_TOKEN = 0xB4467E8D621105312a914F1D42f10770C0Ffe3c8;
    address public constant FLASH_PROTOCOL = 0xEc02f813404656E2A2AEd5BaeEd41D785324E8D0;

    mapping(bytes32 => uint256) public stakerReward;
    mapping(address => address) public pools; // token -> pools

    event PoolCreated(address _pool, address _token);

    event Staked(bytes32 _id, uint256 _rewardAmount, address _pool);

    event LiquidityAdded(address _pool, uint256 _amountFLASH, uint256 _amountALT, uint256 _liquidity, address _sender);

    event LiquidityRemoved(
        address _pool,
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _liquidity,
        address _sender
    );

    event Swapped(address _sender, uint256 _swapAmount, uint256 _flashReceived, address _pool);

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
        address _staker,
        bytes calldata _data
    ) external override onlyProtocol returns (uint256) {
        (address token, uint256 expectedOutput) = abi.decode(_data, (address, uint256));
        address pool = pools[token];
        IERC20(FLASH_TOKEN).transfer(pool, _mintedAmount);
        uint256 reward = IPool(pool).stakeWithFeeRewardDistribution(_mintedAmount, _staker, expectedOutput);
        stakerReward[_id] = reward;
        emit Staked(_id, reward, pool);
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

        emit Swapped(user, _altQuantity, result, pool);
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

        (uint256 amountFLASH, uint256 amountALT, uint256 liquidity) =
            IPool(pool).addLiquidity(_amountFLASH, _amountALT, _amountFLASHMin, _amountALTMin, maker);

        IERC20(FLASH_TOKEN).transferFrom(maker, address(this), amountFLASH);
        IERC20(FLASH_TOKEN).transfer(pool, amountFLASH);
        IERC20(_token).transferFrom(maker, address(this), amountALT);
        IERC20(_token).transfer(pool, amountALT);

        emit LiquidityAdded(pool, amountFLASH, amountALT, liquidity, maker);
    }

    function removeLiquidityInPool(uint256 _liquidity, address _token) public {
        address maker = msg.sender;

        address pool = pools[_token];

        require(pool != address(0), "FlashApp:: POOL_DOESNT_EXIST");

        IERC20(pool).transferFrom(maker, address(this), _liquidity);
        IERC20(pool).transfer(pool, _liquidity);

        (uint256 amountFLASH, uint256 amountALT) = IPool(pool).removeLiquidity(maker);

        emit LiquidityRemoved(pool, amountFLASH, amountALT, _liquidity, maker);
    }

    function removeLiquidityInPoolWithPermit(
        uint256 _liquidity,
        address _token,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public {
        address maker = msg.sender;

        address pool = pools[_token];

        require(pool != address(0), "FlashApp:: POOL_DOESNT_EXIST");

        IFlashToken(FLASH_TOKEN).permit(maker, pool, type(uint256).max, _deadline, _v, _r, _s);

        IERC20(FLASH_TOKEN).transferFrom(maker, pool, _liquidity);

        (uint256 amountFLASH, uint256 amountALT) = IPool(pool).removeLiquidity(maker);

        emit LiquidityRemoved(pool, amountFLASH, amountALT, _liquidity, maker);
    }
}
