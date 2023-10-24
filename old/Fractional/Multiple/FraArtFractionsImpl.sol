// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../custom-lib/SafeERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract FraArtFractionsImpl is ERC721Holder, ERC20, ReentrancyGuard
{
	using SafeERC20 for IERC20;
	using SafeERC721 for IERC721;
	using SafeERC721 for IERC721Metadata;
	using Strings for uint256;

	address[] public targets;
	uint256[] public tokenIds;
	uint256 public fractionsCount;
	uint256 public fractionPrice;
	address public paymentToken;

	bool public released;

	string private name_;
	string private symbol_;
	uint8 private decimals_;

	constructor () ERC20("Fractions", "FRAC") {}

	function name() public view override returns (string memory _name) {
		return name_;
	}

	function symbol() public view override returns (string memory _symbol) {
		return symbol_;
	}

    function decimals() public view override returns (uint8) {
        return decimals_;
    }

	function initialize(address _from, address[] memory _targets, uint256[] memory _tokenIds, 
		string memory _name, string memory _symbol, uint8 _decimals, uint256 _fractionsCount, uint256 _fractionPrice, address _paymentToken) 
	external {
		require(_targets.length == _tokenIds.length, "Length mismatch!");
		for (uint256 i = 0; i < _targets.length; i++) {
			require(IERC721(_targets[i]).ownerOf(_tokenIds[i]) == address(this), "Token not staked");
		}
		require(_fractionsCount  > 0, "invalid fraction count");
		require(_fractionsCount * _fractionPrice / _fractionsCount == _fractionPrice, "invalid fraction price");
		targets = _targets;
		tokenIds = _tokenIds;
		fractionsCount = _fractionsCount;
		fractionPrice = _fractionPrice;
		paymentToken = _paymentToken;
		released = false;
		name_ = _name;
		symbol_ = _symbol;
		decimals_ = _decimals;
		_mint(_from, _fractionsCount);
	}

	function reservePrice() public view returns (uint256 _reservePrice) {
		return fractionsCount * fractionPrice;
	}

	function redeemAmountOf(address _from) public view returns (uint256 _redeemAmount) {
		require(!released, "token already redeemed");
		uint256 _fractionsCount = balanceOf(_from);
		uint256 _reservePrice = reservePrice();
		return _reservePrice - _fractionsCount * fractionPrice;
	}

	function vaultBalance() external view returns (uint256 _vaultBalance) {
		if (!released) return 0;
		uint256 _fractionsCount = totalSupply();
		return _fractionsCount * fractionPrice;
	}

	function vaultBalanceOf(address _from) public view returns (uint256 _vaultBalanceOf) {
		if (!released) return 0;
		uint256 _fractionsCount = balanceOf(_from);
		return _fractionsCount * fractionPrice;
	}

	function redeem() external payable nonReentrant {
		address payable _from = payable(msg.sender);
		uint256 _value = msg.value;
		require(!released, "token already redeemed");
		uint256 _fractionsCount = balanceOf(_from);
		uint256 _redeemAmount = redeemAmountOf(_from);
		released = true;
		if (_fractionsCount > 0) _burn(_from, _fractionsCount);
		_safeTransferFrom(paymentToken, _from, _value, payable(address(this)), _redeemAmount);
		for (uint256 i = 0; i < targets.length; i++) {
			IERC721(targets[i]).safeTransfer(_from, tokenIds[i]);
		}
		emit Redeem(_from, _fractionsCount, _redeemAmount);
		_cleanup();
	}

	function claim() external nonReentrant {
		address payable _from = payable(msg.sender);
		require(released, "token not redeemed");
		uint256 _fractionsCount = balanceOf(_from);
		require(_fractionsCount > 0, "nothing to claim");
		uint256 _claimAmount = vaultBalanceOf(_from);
		_burn(_from, _fractionsCount);
		_safeTransfer(paymentToken, _from, _claimAmount);
		emit Claim(_from, _fractionsCount, _claimAmount);
		_cleanup();
	}

	function _cleanup() internal {
		uint256 _fractionsCount = totalSupply();
		if (_fractionsCount == 0) {
			selfdestruct(payable(address(0x0)));
		}
	}

	function _safeTransfer(address _token, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			_to.transfer(_amount);
		} else {
			IERC20(_token).safeTransfer(_to, _amount);
		}
	}

	function _safeTransferFrom(address _token, address payable _from, uint256 _value, address payable _to, uint256 _amount) internal
	{
		if (_token == address(0)) {
			require(_value == _amount, "invalid value");
			if (_to != address(this)) _to.transfer(_amount);
		} else {
			require(_value == 0, "invalid value");
			IERC20(_token).safeTransferFrom(_from, _to, _amount);
		}
	}

	event Redeem(address indexed _from, uint256 _fractionsCount, uint256 _redeemAmount);
	event Claim(address indexed _from, uint256 _fractionsCount, uint256 _claimAmount);
}