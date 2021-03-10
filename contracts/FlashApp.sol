// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IERC20.sol";
import "./interfaces/IFlashReceiver.sol";
import "./interfaces/IFlashReceiver.sol";
import "./interfaces/IFlashProtocol.sol";

import "./libraries/SafeMath.sol";
import "./libraries/Address.sol";
import "./libraries/Create2.sol";

import "./pool/contracts/Pool.sol";

contract FlashApp is IFlashReceiver {
    using SafeMath for uint256;

    address public constant FLASH_TOKEN = 0x81224010f2eF1f951439f9816f05E1e62b9e45Df;
    address public constant FLASH_PROTOCOL = 0xEe3F542B127fFE3bb1AEeee4B09e2E8d51C6E6A3;

    bytes4 private constant TRANSFER_SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));
    bytes4 private constant TRANSFER_FROM_SELECTOR = bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

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

    function _safeTransfer(
        address _token,
        address _to,
        uint256 _value
    ) private {
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(TRANSFER_SELECTOR, _to, _value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Pool:: TRANSFER_FAILED");
    }

    function _safeTransferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _value
    ) private {
        (bool success, bytes memory data) =
            _token.call(abi.encodeWithSelector(TRANSFER_FROM_SELECTOR, _from, _to, _value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Pool:: TRANSFER_FROM_FAILED");
    }

    function initialize(address _token) public override onlyFactory {
        token = _token;
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
        _safeTransfer(FLASH_TOKEN, pool, _mintedAmount);
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

        _safeTransferFrom(_token, user, address(this), _altQuantity);
        _safeTransfer(_token, pool, _altQuantity);

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

        _safeTransferFrom(FLASH_TOKEN, maker, address(this), amountFLASH);
        _safeTransfer(FLASH_TOKEN, pool, amountFLASH);
        _safeTransferFrom(_token, maker, address(this), amountALT);
        _safeTransfer(_token, pool, amountALT);

        emit LiquidityAdded(pool, amountFLASH, amountALT, liquidity, maker);
    }

    function removeLiquidityInPool(uint256 _liquidity, address _token) public {
        address maker = msg.sender;

        address pool = pools[_token];

        require(pool != address(0), "FlashApp:: POOL_DOESNT_EXIST");

        _safeTransferFrom(pool, maker, address(this), _liquidity);
        _safeTransfer(pool, pool, _liquidity);

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

        IERC20(pool).permit(maker, pool, type(uint256).max, _deadline, _v, _r, _s);

        _safeTransferFrom(pool, maker, pool, _liquidity);

        (uint256 amountFLASH, uint256 amountALT) = IPool(pool).removeLiquidity(maker);

        emit LiquidityRemoved(pool, amountFLASH, amountALT, _liquidity, maker);
    }
}
