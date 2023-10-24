// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../custom-lib/Auth.sol";

contract FraArtMarket is Auth, ERC721Holder {
    using SafeMath for uint256;
    using Address for address;

    uint256 constant public PERCENTS_DIVIDER = 1000;
    uint256 public swapFee = 25;  // 2.5% for admin tx fee
    address public swapFeeAddress;

    /* Pairs to market NFT _id => price */
    struct Pair {
        uint256 pair_id;
        address collection;
        uint256 token_id;
        address owner;
        uint256 price;
        bool bValid;
    }
    uint256 public currentID;
    // token id => Pair mapping
    mapping(uint256 => Pair) public pairs;

    event ItemListed(Pair pair);
    event ItemDelisted(uint256 id);
    event Swapped(address buyer, Pair pair);

    constructor () Auth(msg.sender) { swapFeeAddress = msg.sender; }

    function setFee(uint256 _swapFee, address _swapFeeAddress) external authorized {
        swapFee = _swapFee;
        swapFeeAddress = _swapFeeAddress;
    }

    function list(
        address _collection, 
        uint256 _token_id, 
        uint256 _price
    ) OnlyItemOwner(_collection, _token_id) external {
        require(_price > 0, "Invalid price");
        IERC721 nft = IERC721(_collection);
        nft.safeTransferFrom(msg.sender, address(this), _token_id);
        // Create new pair item
        currentID = currentID.add(1);
        Pair memory item;
        item.pair_id = currentID;
        item.collection = _collection;
        item.token_id = _token_id;
        item.owner = msg.sender;
        item.price = _price;
        item.bValid = true;
        pairs[currentID] = item;
        emit ItemListed(item);
    }

    function delist(uint256 _id) external {
        require(pairs[_id].bValid && msg.sender == pairs[_id].owner, "Unauthorized owner");
        IERC721(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pairs[_id].token_id);
        pairs[_id].bValid = false;
        pairs[_id].price = 0;
        emit ItemDelisted(_id);
    }

    function buy(uint256 _id) external payable {
        require(_id <= currentID && pairs[_id].bValid, "Invalid Pair Id");
        require(pairs[_id].owner != msg.sender, "Owner can not buy");

        Pair memory pair = pairs[_id];
        uint256 totalAmount = pair.price;
        require(msg.value >= totalAmount, "insufficient balance");
        
        uint256 feeAmount = totalAmount.mul(swapFee).div(PERCENTS_DIVIDER);
        uint256 sellerAmount = totalAmount.sub(feeAmount);
        if(swapFee > 0) {
            (bool fs, ) = payable(swapFeeAddress).call{value: feeAmount}("");
            require(fs, "Failed to send fee to fee address");
        }
        (bool os, ) = payable(pair.owner).call{value: sellerAmount}("");
        require(os, "Failed to send to item owner"); 
        
        // transfer NFT token to buyer
        IERC721(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.token_id);
        pairs[_id].bValid = false;

        emit Swapped(msg.sender, pair);
    }

    modifier OnlyItemOwner(address _collection, uint256 _tokenId) {
        IERC721 collectionContract = IERC721(_collection);
        require(collectionContract.ownerOf(_tokenId) == msg.sender);
        _;
    }

    function withdraw() external payable authorized {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
}
