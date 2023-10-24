// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FraArtFractionsImpl.sol";

contract FraArtFractionalizer is ReentrancyGuard
{
    function fractionalize(
        address[] memory _targets, 
        uint256[] memory _tokenIds, 
        string memory _name, 
        string memory _symbol, 
        uint8 _decimals, 
        uint256 _fractionsCount, 
        uint256 _fractionPrice, 
        address _paymentToken
    ) external nonReentrant returns(address _fractions) {
        require(_targets.length == _tokenIds.length, "Length mismatch!");
        address _from = msg.sender;
        bytes memory bytecode = type(FraArtFractionsImpl).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_name, _symbol, block.timestamp));
        assembly {
            _fractions := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        for (uint256 i = 0; i < _targets.length; i++) {
            IERC721(_targets[i]).transferFrom(_from, _fractions, _tokenIds[i]);
        }
        FraArtFractionsImpl(_fractions).initialize(_from, _targets, _tokenIds, _name, _symbol, _decimals, _fractionsCount, _fractionPrice, _paymentToken);
        emit Fractionalize(_from, _targets, _tokenIds, _fractions, _name, _symbol, _decimals, _fractionsCount, _fractionPrice, _paymentToken);
    }

    event Fractionalize(address indexed _from, address[] _targets, uint256[] _tokenIds, address _fractions, 
        string name, string symbol, uint8 decimals, uint256 supply, uint256 price, address payToken);
}