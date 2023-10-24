// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../custom-lib/Auth.sol";
import "./GodwokenMultipleNFT.sol";

interface IGodwokenMultipleNFT {
	function initialize(string memory _name, string memory _symbol, string memory _uri, address _creator, uint256 _royalty, bool _isPublic) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function creatorOf(uint256 _tokenId) external view returns (address);
    function royalty() external view returns (uint256);
}

contract GodwokenMultipleFactory is Auth {
    using SafeMath for uint256;

    address[] public collections;
    uint256 public MAX_COLLECTION_ROYALTY = 500; // 50%
    /** Events */
    event MultipleCollectionCreated(address collection_address, address owner, string name, string symbol, string uri, uint256 royalty, bool isPublic);

    constructor() Auth(msg.sender) {}

    function createMultipleCollection(
        string memory _name, 
        string memory _symbol, 
        string memory _uri, 
        uint256 _royalty, 
        bool _isPublic
    ) external returns(address collection) {
        require(_royalty <= MAX_COLLECTION_ROYALTY, "invalid royalties");
        bytes memory bytecode = type(GodwokenMultipleNFT).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_uri, _name, block.timestamp));
        assembly {
            collection := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IGodwokenMultipleNFT(collection).initialize(_name, _symbol, _uri, msg.sender, _royalty, _isPublic);
        collections.push(collection);
        emit MultipleCollectionCreated(collection, msg.sender, _name, _symbol, _uri, _royalty, _isPublic);
    }

    function withdraw() external authorized {
        uint balance = address(this).balance;
        require(balance > 0, "insufficient balance");
        (bool result, ) = payable(msg.sender).call{value: balance}("");
        require(result, "Failed to withdraw balance"); 
    }

    /**
     * @dev To receive ETH
     */
    receive() external payable {}
    
    function updateRoyaltyLimit(uint256 newLimit) external authorized {
        MAX_COLLECTION_ROYALTY = newLimit;
    }
}