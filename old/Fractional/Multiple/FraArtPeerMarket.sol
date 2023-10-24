// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FraPeerMarkets is ReentrancyGuard
{
	using Address for address payable;
	using ECDSA for bytes32;
	using SafeERC20 for IERC20;
	using SafeMath for uint256;

	bytes32 constant TYPEHASH = keccak256("Order(address,address,uint256,uint256,address,uint256)");

	mapping (bytes32 => uint256) public executedBookAmounts;

	uint256 public immutable fee;
	address payable public immutable vault;

	uint256 private immutable chainId_;

	constructor (uint256 _fee, address payable _vault) {
		require(_fee <= 1e18, "invalid fee");
		require(_vault != address(0), "invalid address");
		fee = _fee;
		vault = _vault;
		chainId_ = _chainId();
	}

	function generateOrderId(address _bookToken, address _execToken, uint256 _bookAmount, uint256 _execAmount, address payable _maker, uint256 _salt) public view returns (bytes32 _orderId) {
		return keccak256(abi.encodePacked(TYPEHASH, chainId_, address(this), _bookToken, _execToken, _bookAmount, _execAmount, _maker, _salt));
	}

	function checkOrderExecution(address _bookToken, address _execToken, uint256 _bookAmount, uint256 _execAmount, address payable _maker, uint256 _salt, uint256 _requiredBookAmount) external view returns (uint256 _totalExecAmount) {
		return _checkOrderExecution(_bookToken, _execToken, _bookAmount, _execAmount, _maker, _salt, _requiredBookAmount);
	}

	// availability may not be accurate for multiple orders of the same maker
	function checkOrdersExecution(address _bookToken, address _execToken, uint256[] calldata _bookAmounts, uint256[] calldata _execAmounts, address payable[] calldata _makers, uint256[] calldata _salts, uint256 _lastRequiredBookAmount) external view returns (uint256 _totalExecAmount) {
		uint256 _length = _makers.length;
		if (_length == 0) return 0;
		_totalExecAmount = 0;
		for (uint256 _i = 0; _i < _length - 1; _i++) {
			uint256 _localExecAmount = _checkOrderExecution(_bookToken, _execToken, _bookAmounts[_i], _execAmounts[_i], _makers[_i], _salts[_i], type(uint256).max);
			uint256 _newTotalExecAmount = _totalExecAmount + _localExecAmount;
			if (_newTotalExecAmount <= _totalExecAmount) return 0;
			_totalExecAmount = _newTotalExecAmount;
		}
		{
			uint256 _i = _length - 1;
			uint256 _localExecAmount = _checkOrderExecution(_bookToken, _execToken, _bookAmounts[_i], _execAmounts[_i], _makers[_i], _salts[_i], _lastRequiredBookAmount);
			uint256 _newTotalExecAmount = _totalExecAmount + _localExecAmount;
			if (_newTotalExecAmount <= _totalExecAmount) return 0;
			_totalExecAmount = _newTotalExecAmount;
		}
		return _totalExecAmount;
	}

	function _checkOrderExecution(address _bookToken, address _execToken, uint256 _bookAmount, uint256 _execAmount, address payable _maker, uint256 _salt, uint256 _requiredBookAmount) internal view returns (uint256 _requiredExecAmount) {
		if (_requiredBookAmount == 0) return 0;
		bytes32 _orderId = generateOrderId(_bookToken, _execToken, _bookAmount, _execAmount, _maker, _salt);
		uint256 _executedBookAmount = executedBookAmounts[_orderId];
		if (_executedBookAmount >= _bookAmount) return 0;
		uint256 _availableBookAmount = _bookAmount - _executedBookAmount;
		if (_requiredBookAmount == type(uint256).max) {
			_requiredBookAmount = _availableBookAmount;
		} else {
			if (_requiredBookAmount > _availableBookAmount) return 0;
		}
		if (_requiredBookAmount > IERC20(_bookToken).balanceOf(_maker)) return 0;
		if (_requiredBookAmount > IERC20(_bookToken).allowance(_maker, address(this))) return 0;
		_requiredExecAmount = _requiredBookAmount.mul(_execAmount).add(_bookAmount - 1) / _bookAmount;
		return _requiredExecAmount;
	}

	function executeOrder(address _bookToken, address _execToken, uint256 _bookAmount, uint256 _execAmount, address payable _maker, uint256 _salt, bytes calldata _signature, uint256 _requiredBookAmount) external payable nonReentrant {
		address payable _taker = payable(msg.sender);
		uint256 _totalExecFeeAmount = _executeOrder(_bookToken, _execToken, _bookAmount, _execAmount, _maker, _salt, _signature, _taker, _requiredBookAmount);
		if (_execToken == address(0)) {
			vault.sendValue(_totalExecFeeAmount);
			require(address(this).balance == 0, "excess value");
		} else {
			IERC20(_execToken).safeTransferFrom(_taker, vault, _totalExecFeeAmount);
		}
	}

	function executeOrders(address _bookToken, address _execToken, uint256[] memory _bookAmounts, uint256[] memory _execAmounts, address payable[] memory _makers, uint256[] memory _salts, bytes memory _signatures, uint256 _lastRequiredBookAmount) external payable nonReentrant {
		address payable _taker = payable(msg.sender);
		uint256 _length = _makers.length;
		require(_length > 0, "invalid length");
		uint256 _totalExecFeeAmount = 0;
		for (uint256 _i = 0; _i < _length - 1; _i++) {
			bytes memory _signature = _extractSignature(_signatures, _i);
			uint256 _requiredExecFeeAmount = _executeOrder(_bookToken, _execToken, _bookAmounts[_i], _execAmounts[_i], _makers[_i], _salts[_i], _signature, _taker, type(uint256).max);
			_totalExecFeeAmount = _totalExecFeeAmount.add(_requiredExecFeeAmount);
		}
		{
			uint256 _i = _length - 1;
			bytes memory _signature = _extractSignature(_signatures, _i);
			uint256 _requiredExecFeeAmount = _executeOrder(_bookToken, _execToken, _bookAmounts[_i], _execAmounts[_i], _makers[_i], _salts[_i], _signature, _taker, _lastRequiredBookAmount);
			_totalExecFeeAmount = _totalExecFeeAmount.add(_requiredExecFeeAmount);
		}
		if (_execToken == address(0)) {
			vault.sendValue(_totalExecFeeAmount);
			require(address(this).balance == 0);
		} else {
			IERC20(_execToken).safeTransferFrom(_taker, vault, _totalExecFeeAmount);
		}
	}

	function _executeOrder(address _bookToken, address _execToken, uint256 _bookAmount, uint256 _execAmount, address payable _maker, uint256 _salt, bytes memory _signature, address payable _taker, uint256 _requiredBookAmount) internal returns (uint256 _requiredExecFeeAmount) {
		require(_requiredBookAmount > 0, "invalid amount");
		bytes32 _orderId = generateOrderId(_bookToken, _execToken, _bookAmount, _execAmount, _maker, _salt);
		require(_maker == _recoverSigner(_orderId, _signature), "access denied");
		uint256 _requiredExecNetAmount;
		{
			uint256 _executedBookAmount = executedBookAmounts[_orderId];
			require(_executedBookAmount < _bookAmount, "inactive order");
			{
				uint64 _startTime = uint64(_salt >> 64);
				uint64 _endTime = uint64(_salt);
				require(_startTime <= block.timestamp && block.timestamp < _endTime, "invalid timeframe");
			}
			uint256 _availableBookAmount = _bookAmount - _executedBookAmount;
			if (_requiredBookAmount == type(uint256).max) {
				_requiredBookAmount = _availableBookAmount;
			} else {
				require(_requiredBookAmount <= _availableBookAmount, "insufficient liquidity");
			}
			uint256 _requiredExecAmount = _requiredBookAmount.mul(_execAmount).add(_bookAmount - 1) / _bookAmount;
			_requiredExecFeeAmount = _requiredExecAmount.mul(fee) / 1e18;
			_requiredExecNetAmount = _requiredExecAmount - _requiredExecFeeAmount;
			executedBookAmounts[_orderId] = _executedBookAmount + _requiredBookAmount;
		}
		IERC20(_bookToken).safeTransferFrom(_maker, _taker, _requiredBookAmount);
		if (_execToken == address(0)) {
			_maker.sendValue(_requiredExecNetAmount);
		} else {
			IERC20(_execToken).safeTransferFrom(_taker, _maker, _requiredExecNetAmount);
		}
		emit Trade(_bookToken, _execToken, _orderId, _requiredBookAmount, _requiredExecNetAmount, _requiredExecFeeAmount, _maker, _taker);
		return _requiredExecFeeAmount;
	}

	function cancelOrder(address _bookToken, address _execToken, uint256 _bookAmount, uint256 _execAmount, uint256 _salt) external {
		address payable _maker = payable(msg.sender);
		_cancelOrder(_bookToken, _execToken, _bookAmount, _execAmount, _maker, _salt);
	}

	function cancelOrders(address _bookToken, address _execToken, uint256[] calldata _bookAmounts, uint256[] calldata _execAmounts, uint256[] calldata _salts) external {
		address payable _maker = payable(msg.sender);
		for (uint256 _i = 0; _i < _bookAmounts.length; _i++) {
			_cancelOrder(_bookToken, _execToken, _bookAmounts[_i], _execAmounts[_i], _maker, _salts[_i]);
		}
	}

	function _cancelOrder(address _bookToken, address _execToken, uint256 _bookAmount, uint256 _execAmount, address payable _maker, uint256 _salt) internal {
		bytes32 _orderId = generateOrderId(_bookToken, _execToken, _bookAmount, _execAmount, _maker, _salt);
		executedBookAmounts[_orderId] = type(uint256).max;
		emit CancelOrder(_bookToken, _execToken, _orderId);
	}

	function _extractSignature(bytes memory _signatures, uint256 _index) internal pure returns (bytes memory _signature) {
		uint256 _offset = 65 * _index;
		_signature = new bytes(65);
		for (uint256 _i = 0; _i < 65; _i++) {
			_signature[_i] = _signatures[_offset + _i];
		}
		return _signature;
	}

	function _recoverSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address _signer) {
		return _hash.toEthSignedMessageHash().recover(_signature);
	}

	function _chainId() internal view returns (uint256 _chainid) {
		assembly { _chainid := chainid() }
		return _chainid;
	}

	event Trade(address indexed _bookToken, address indexed _execToken, bytes32 indexed _orderId, uint256 _bookAmount, uint256 _execAmount, uint256 _execFeeAmount, address _maker, address _taker);
	event CancelOrder(address indexed _bookToken, address indexed _execToken, bytes32 indexed _orderId);
}