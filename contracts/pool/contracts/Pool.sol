pragma solidity ^0.6.8;

import "../../libraries/SafeMath.sol";
import "./PoolERC20.sol";
import "../interfaces/IERC20.sol";

contract Pool is PoolERC20, IPool {
    using SafeMath for uint256;

    address
        public constant FLASH_TOKEN = 0x706AEa632c07D34C9FF9EA419bf19c85dBA4Dcb8;
    address public token;
    address public factory;
    address public FLASH_PROTOCOL = 0x9B5C5499d22dCB7F4FEbEC4159349095D8E4156E;
    uint256 public reserveFlashAmount;
    uint256 public reserveAltAmount;
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    modifier onlyFactory() {
        require(msg.sender == factory);
        _;
    }


    constructor() public {
        factory = msg.sender;
    }


    function initialize(address _flashAddress, address _token) public {
        require(msg.sender == factory);
        FLASH_CONTRACT = _flashAddress;
        token = _token;
    }

    function getAPYStake(uint256 _amountIn)
        public
        view
        returns (uint256 result)
    {
        uint256 amountInWithFee = _amountIn.mul(900);
        uint256 num = amountInWithFee.mul(reserveAltAmount);
        uint256 den = (reserveFlashAmount.mul(1000)).add(amountInWithFee);
        result = num.div(den);
    }

    function getAPYSwap(uint256 _amountIn)
        public
        view
        returns (uint256 result)
    {
        uint256 amountInWithFee = _amountIn.mul(900);
        uint256 num = amountInWithFee.mul(reserveFlashAmount);
        uint256 den = (reserveAltAmount.mul(1000)).add(amountInWithFee);
        result = num.div(den);
    }

    function swapWithFeeRewardDistribution(
        uint256 _amountIn,
        address _staker,
        uint256 _expectedOutput
    ) public override onlyFactory returns (uint256 result) {
        result = getAPYSwap(_amountIn);
        require(_expectedOutput <= result, "Pool:: EXPECTED_IS_GREATER");
        calcNewReserveSwap(_amountIn, result);
        IERC20(FLASH_CONTRACT).transfer(_staker, result);
    }

    function stakeWithFeeRewardDistribution(
        uint256 _amountIn,
        address _staker,
        uint256 _expectedOutput
    ) public override onlyFactory returns (uint256 result) {
        result = getAPYStake(_amountIn);
        require(_expectedOutput <= result, "Pool:: EXPECTED_IS_GREATER");
        calcNewReserveStake(_amountIn, result);
        IERC20(token).transfer(_staker, result);
    }

    function calcNewReserveStake(uint256 _amountIn, uint256 _amountOut)
        private
    {
        reserveFlashAmount = reserveFlashAmount.add(_amountIn);
        reserveAltAmount = reserveAltAmount.sub(_amountOut);
    }

    function calcNewReserveSwap(uint256 _amountIn, uint256 _amountOut) private {
        reserveFlashAmount = reserveFlashAmount.sub(_amountOut);
        reserveAltAmount = reserveAltAmount.add(_amountIn);
    }

    function calcNewReserveAddLiquidity(uint256 _amountFLASH, uint256 _amountALT)
        private
    {
        reserveFlashAmount = reserveFlashAmount.add(_amountFLASH);
        reserveAltAmount = reserveAltAmount.add(_amountALT);
    }

    function calcNewReserveRemoveLiquidity(
        uint256 _amountFLASH,
        uint256 _amountALT
    ) private {
        reserveFlashAmount = reserveFlashAmount.sub(_amountFLASH);
        reserveAltAmount = reserveAltAmount.sub(_amountALT);
    }

    function _addLiquidity(
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _amountFLASHMin,
        uint256 _amountALTMin
    ) private returns (uint256 amountFLASH, uint256 amountALT) {
        if (reserveAltAmount == 0 && reserveFlashAmount == 0) {
            (amountFLASH, amountALT) = (_amountFLASH, _amountALT);
        } else {
            uint256 amountALTQuote = quote(
                _amountFLASH,
                reserveFlashAmount,
                reserveAltAmount
            );
            if (amountALTQuote <= _amountALT) {
                require(
                    amountALTQuote >= _amountALTMin,
                    "Pool:: INSUFFICIENT_B_AMOUNT"
                );
                (amountFLASH, amountALT) = (_amountFLASH, amountALTQuote);
            } else {
                uint256 amountFLASHQuote = quote(
                    _amountALT,
                    reserveAltAmount,
                    reserveFlashAmount
                );
                require(
                    (amountFLASHQuote <= _amountFLASH) &&
                        (amountFLASHQuote >= _amountFLASHMin),
                    "Pool:: INSUFFICIENT_A_AMOUNT"
                );
                (amountFLASH, amountALT) = (amountFLASHQuote, _amountALT);
            }
        }
    }

    function mintLiquidityTokens(
        address _to,
        uint256 _flashAmount,
        uint256 _altAmount
    ) private returns (uint256 liquidity) {
        if (totalSupply == 0) {
            liquidity = Math.sqrt(_flashAmount.mul(_altAmount)).sub(
                MINIMUM_LIQUIDITY
            );
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                _flashAmount.mul(totalSupply) / reserveFlashAmount,
                _altAmount.mul(totalSupply) / reserveAltAmount
            );
        }
        require(liquidity > 0, "Pool:: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(_to, liquidity);
    }

    function addLiquidity(
        uint256 _amountFLASH,
        uint256 _amountALT,
        uint256 _amountFLASHMin,
        uint256 _amountALTMin,
        address _maker
    )
        public
        override
        onlyFactory
        returns (
            uint256 amountFLASH,
            uint256 amountALT,
            uint256 liquidity
        )
    {
        (amountFLASH, amountALT) = _addLiquidity(
            _amountFLASH,
            _amountALT,
            _amountFLASHMin,
            _amountALTMin
        );
        liquidity = mintLiquidityTokens(_maker, amountFLASH, amountALT);
        calcNewReserveAddLiquidity(amountFLASH,amountALT);
    }

    function removeLiquidity(address _maker)
        public
        override
        onlyFactory
        returns (uint256 amountFLASH, uint256 amountALT)
    {
        (amountFLASH, amountALT) = burn(_maker);
    }

    function burn(address to)
        internal
        returns (uint256 amountFLASH, uint256 amountALT)
    {
        uint256 balanceFLASH = IERC20(FLASH_CONTRACT).balanceOf(address(this));
        uint256 balanceALT = IERC20(token).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        amountFLASH = liquidity.mul(balanceFLASH) / totalSupply; 
        amountALT = liquidity.mul(balanceALT) / totalSupply; 
        require(
            amountFLASH > 0 && amountALT > 0,
            "Pool:: INSUFFICIENT_LIQUIDITY_BURNED"
        );
        _burn(address(this), liquidity);
        IERC20(FLASH_CONTRACT).transfer(to, amountFLASH);
        IERC20(token).transfer(to, amountALT);
        balanceFLASH = balanceFLASH.sub(IERC20(FLASH_CONTRACT).balanceOf(address(this)));
        balanceALT = balanceALT.sub(IERC20(token).balanceOf(address(this)));

        calcNewReserveRemoveLiquidity(balanceFLASH, balanceALT);
    }

    function quote(
        uint256 _amountA,
        uint256 _reserveA,
        uint256 _reserveB
    ) public pure returns (uint256 amountB) {
        require(_amountA > 0, "Pool:: INSUFFICIENT_AMOUNT");
        require(_reserveA > 0 && _reserveB > 0, "Pool:: INSUFFICIENT_LIQUIDITY");
        amountB = _amountA.mul(_reserveB).div(_reserveA);
    }
}