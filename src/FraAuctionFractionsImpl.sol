// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../custom-lib/SafeERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract FraAuctionFractionsImpl is ERC721Holder, ERC20, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC721 for IERC721;
    using SafeERC721 for IERC721Metadata;
    using SafeMath for uint256;
    using Address for address;

    address public target;
    uint256 public tokenId;
    uint256 public fractionsCount;
    uint256 public fractionPrice;
    uint256 public kickoff;
    uint256 public duration;
    uint256 public fee;
    address public marketer;
    uint256 constant _UNIT = 10000;

    bool public released;
    uint256 public cutoff;
    address payable public bidder;

    uint256 private lockedFractions_;
    uint256 private lockedAmount_;

    string private name_;
    string private symbol_;

    constructor () ERC20("Fractions", "FRAC") {
        target = address(type(uint160).max); // prevents proxy code from misuse
    }

    function name() public view override returns (string memory _name) {
        return name_;
    }

    function symbol() public view override returns (string memory _symbol) {
        return symbol_;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender), "access denied");
        _;
    }

    modifier onlyHolder() {
        require(balanceOf(msg.sender) > 0, "access denied");
        _;
    }

    modifier onlyBidder() {
        require(msg.sender == bidder, "access denied");
        _;
    }

    modifier inAuction() {
        require(kickoff <= block.timestamp && block.timestamp <= cutoff, "not available");
        _;
    }

    modifier afterAuction() {
        require(block.timestamp > cutoff, "not available");
        _;
    }

    function initialize(
        address _from, 
        address _target, 
        uint256 _tokenId, 
        string memory _name, 
        string memory _symbol, 
        uint256 _fractionsCount, 
        uint256 _fractionPrice, 
        uint256 _kickoff, 
        uint256 _duration, 
        uint256 _fee, 
        address _marketer
    ) external {
        require(target == address(type(uint160).max), "already initialized");
        require(IERC721(_target).ownerOf(_tokenId) == address(this), "missing token");
        require(_fractionsCount > 0, "invalid count");
        require(_fractionsCount * _fractionPrice / _fractionsCount == _fractionPrice, "price overflow");
        require(_kickoff <= block.timestamp + 731 days, "invalid kickoff");
        require(30 minutes <= _duration && _duration <= 731 days, "invalid duration");
        require(_fee <= 1e18, "invalid fee");
        require(_marketer != address(0), "invalid address");
        target = _target;
        tokenId = _tokenId;
        fractionsCount = _fractionsCount;
        fractionPrice = _fractionPrice / (10 ** decimals());
        kickoff = _kickoff;
        duration = _duration;
        fee = _fee;
        marketer = _marketer;
        released = false;
        cutoff = type(uint256).max;
        bidder = payable(address(0));
        name_ = _name;
        symbol_ = _symbol;
        lockedFractions_ = 0;
        lockedAmount_ = 0;
        _mint(_from, _fractionsCount);
    }

    function status() external view returns (string memory _status) {
        return bidder == address(0) ? block.timestamp < kickoff ? "PAUSE" : "OFFER" : block.timestamp > cutoff ? "SOLD" : "AUCTION";
    }

    function isOwner(address _from) public view returns (bool _soleOwner) {
        return bidder == address(0) && balanceOf(_from) + lockedFractions_ == fractionsCount;
    }

    function reservePrice() external view returns (uint256 _reservePrice) {
        return fractionsCount * fractionPrice;
    }

    function bidRangeOf(address _from) external view inAuction returns (uint256 _minFractionPrice, uint256 _maxFractionPrice) {
        if (bidder == address(0)) {
            _minFractionPrice = fractionPrice;
        } else {
            _minFractionPrice = (fractionPrice * 11 + 9) / 10; // 10% increase, rounded up
        }
        uint256 _fractionsCount = balanceOf(_from);
        if (bidder == _from) _fractionsCount += lockedFractions_;
        if (_fractionsCount == 0) {
            _maxFractionPrice = type(uint256).max;
        } else {
            _maxFractionPrice = _minFractionPrice + (fractionsCount * fractionsCount * fractionPrice) / (_fractionsCount * _fractionsCount * 100); // 1% / (ownership ^ 2)
        }
        return (_minFractionPrice, _maxFractionPrice);
    }

    function bidAmountOf(address _from, uint256 _newFractionPrice) external view inAuction returns (uint256 _bidAmount) {
        uint256 _fractionsCount = balanceOf(_from);
        if (bidder == _from) _fractionsCount += lockedFractions_;
        return (fractionsCount - _fractionsCount) * _newFractionPrice;
    }

    function vaultBalance() external view returns (uint256 _vaultBalance) {
        if (block.timestamp <= cutoff) return 0;
        uint256 _fractionsCount = totalSupply();
        return _fractionsCount * fractionPrice;
    }

    function vaultBalanceOf(address _from) external view returns (uint256 _vaultBalanceOf) {
        if (block.timestamp <= cutoff) return 0;
        uint256 _fractionsCount = balanceOf(_from);
        return _fractionsCount * fractionPrice;
    }

    function updatePrice(uint256 _newFractionPrice) external onlyOwner {
        address _from = msg.sender;
        require(fractionsCount * _newFractionPrice / fractionsCount == _newFractionPrice, "price overflow");
        uint256 _oldFractionPrice = fractionPrice;
        fractionPrice = _newFractionPrice;
        emit UpdatePrice(_from, _oldFractionPrice, _newFractionPrice);
    }

    function cancel() external nonReentrant onlyOwner {
        address _from = msg.sender;
        released = true;
        _burn(_from, balanceOf(_from));
        _burn(address(this), lockedFractions_);
        IERC721(target).safeTransfer(_from, tokenId);
        emit Cancel(_from);
        _cleanup();
    }

    function bid(uint256 _newFractionPrice) external payable nonReentrant inAuction {
        address payable _from = payable(msg.sender);
        uint256 _value = msg.value;
        require(fractionsCount * _newFractionPrice / fractionsCount == _newFractionPrice, "price overflow");
        uint256 _oldFractionPrice = fractionPrice;
        uint256 _fractionsCount;
        if (bidder == address(0)) {
            _fractionsCount = balanceOf(_from);
            uint256 _fractionsCount2 = _fractionsCount * _fractionsCount;
            require(_newFractionPrice >= _oldFractionPrice, "below minimum");
            require(_newFractionPrice * _fractionsCount2 * 100 <= _oldFractionPrice * (_fractionsCount2 * 100 + fractionsCount * fractionsCount), "above maximum"); // <= 1% / (ownership ^ 2)
            cutoff = block.timestamp + duration;
        } else {
            if (lockedFractions_ > 0) _transfer(address(this), bidder, lockedFractions_);
            bidder.transfer(lockedAmount_);
            _fractionsCount = balanceOf(_from);
            uint256 _fractionsCount2 = _fractionsCount * _fractionsCount;
            require(_newFractionPrice * 10 >= _oldFractionPrice * 11, "below minimum"); // >= 10%
            require(_newFractionPrice * _fractionsCount2 * 100 <= _oldFractionPrice * (_fractionsCount2 * 110 + fractionsCount * fractionsCount), "above maximum"); // <= 10% + 1% / (ownership ^ 2)
            if (cutoff < block.timestamp + 15 minutes) cutoff = block.timestamp + 15 minutes;
        }
        bidder = _from;
        fractionPrice = _newFractionPrice;
        uint256 _bidAmount = (fractionsCount - _fractionsCount) * _newFractionPrice;
        require(_value >= _bidAmount, "invalid value");
        if (_fractionsCount > 0) _transfer(_from, address(this), _fractionsCount);
        lockedFractions_ = _fractionsCount;
        lockedAmount_ = _bidAmount;
        emit Bid(_from, _oldFractionPrice, _newFractionPrice, _fractionsCount, _bidAmount);
    }

    function redeem() external nonReentrant onlyBidder afterAuction {
        address _from = msg.sender;
        require(!released, "missing token");
        released = true;
        _burn(address(this), lockedFractions_);
        IERC721(target).safeTransfer(_from, tokenId);
        emit Redeem(_from);
        _cleanup();
    }

    function claim() external nonReentrant onlyHolder afterAuction {
        address payable _from = payable(msg.sender);
        uint256 _fractionsCount = balanceOf(_from);
        uint256 _claimAmount = _fractionsCount * fractionPrice;
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
        if (released && _fractionsCount == 0) {
            selfdestruct(payable(address(0)));
        }
    }

    event UpdatePrice(address indexed _from, uint256 _oldFractionPrice, uint256 _newFractionPrice);
    event Cancel(address indexed _from);
    event Bid(address indexed _from, uint256 _oldFractionPrice, uint256 _newFractionPrice, uint256 _fractionsCount, uint256 _bidAmount);
    event Redeem(address indexed _from);
    event Claim(address indexed _from, uint256 _fractionsCount, uint256 _claimAmount);
}