// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FraAuctionFractionsImpl.sol";
import "../custom-lib/Auth.sol";

contract FraAuctionFractionalizer is ReentrancyGuard, Auth {
    address public marketer;
    uint256 public fee;
    uint256 constant _UNIT = 10000;

    constructor () Auth(msg.sender) {
        marketer = msg.sender;
        fee = 250; // 2.5%, unit = 10000
    }

    function setMarketer(address _marketer) external authorized {
        require(_marketer != address(0), "Invalid address");
        marketer = _marketer;
    }

    function setFee(uint256 _fee) external authorized {
        require(_fee < _UNIT, "Exceed max fee");
        fee = _fee;
    }

    function fractionalize(
        address _target, 
        uint256 _tokenId, 
        string memory _name, 
        string memory _symbol, 
        uint256 _fractionsCount, 
        uint256 _fractionPrice, 
        uint256 _kickoff, 
        uint256 _duration
    ) external nonReentrant returns (address _fractions) {
        address _from = msg.sender;
        bytes memory bytecode = type(FraAuctionFractionsImpl).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_name, _symbol, block.timestamp));
        assembly {
            _fractions := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IERC721(_target).transferFrom(_from, _fractions, _tokenId);
        FraAuctionFractionsImpl(_fractions).initialize(_from, _target, _tokenId, _name, _symbol, _fractionsCount, _fractionPrice, _kickoff, _duration, fee, marketer);
        emit Fractionalize(_from, _target, _tokenId, _fractions, _name, _symbol, _fractionsCount, _fractionPrice, _kickoff,_duration);
        return _fractions;
    }

    event Fractionalize(address indexed _from, address indexed _target, uint256 indexed _tokenId, address _fractions,
        string name, string symbol, uint256 supply, uint256 price, uint256 kickoff, uint256 duration);
}