// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../custom-lib/SafeERC721.sol";

contract FraFractionsImpl is ERC721Holder, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC721 for IERC721;
    using SafeERC721 for IERC721Metadata;
    using Strings for uint256;
    using SafeMath for uint256; 

    address public target;
    uint256 public tokenId;
    uint256 public fractionsCount;
    uint256 public fractionPrice;

    address public marketer;
    uint256 public fee;
    uint256 constant _UNIT = 10000;
    bool public released;

    string private name_;
    string private symbol_;

    constructor () ERC20("Fractions", "FRAC") {}

    function name() public view override returns (string memory _name) {
        return name_;
    }

    function symbol() public view override returns (string memory _symbol) {
        return symbol_;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function initialize(
        address _from, 
        address _target, 
        uint256 _tokenId, 
        string memory _name, 
        string memory _symbol, 
        uint256 _fractionsCount, 
        uint256 _fractionPrice,
        address _marketer,
        uint256 _fee
    ) external {
        require(target == address(0), "already initialized");
        require(IERC721(_target).ownerOf(_tokenId) == address(this), "Token not staked");
        require(_fractionsCount  > 0, "invalid fraction count");
        require(_fractionsCount * _fractionPrice / _fractionsCount == _fractionPrice, "invalid fraction price");
        target = _target;
        tokenId = _tokenId;
        fractionsCount = _fractionsCount;
        fractionPrice = _fractionPrice / (10 ** decimals());
        released = false;
        name_ = _name;
        symbol_ = _symbol;
        marketer = _marketer;
        fee = _fee;
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
        require(_value >= _redeemAmount, "invalid value");
        released = true;
        if (_fractionsCount > 0) _burn(_from, _fractionsCount);
        IERC721(target).safeTransfer(_from, tokenId);
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
        uint256 feeAmount = _claimAmount.mul(fee).div(_UNIT);
        uint256 claimAmount = _claimAmount.sub(feeAmount);
        payable(marketer).transfer(feeAmount);
        _from.transfer(claimAmount);
        emit Claim(_from, _fractionsCount, _claimAmount);
        _cleanup();
    }

    function _cleanup() internal {
        uint256 _fractionsCount = totalSupply();
        if (_fractionsCount == 0) {
            selfdestruct(payable(address(0)));
        }
    }

    event Redeem(address indexed _from, uint256 _fractionsCount, uint256 _redeemAmount);
    event Claim(address indexed _from, uint256 _fractionsCount, uint256 _claimAmount);
}