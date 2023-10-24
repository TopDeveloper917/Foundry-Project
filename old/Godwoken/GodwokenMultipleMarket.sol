// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../custom-lib/Auth.sol";

interface IGodwokenMultipleNFT {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function creatorOf(uint256 _tokenId) external view returns (address);
    function royalty() external view returns (uint256);
    function royalties(uint256 _tokenId) external view returns (uint256);
    function collectionOwner() external view returns (address);
}

contract GodwokenMultipleMarket is Auth, ERC1155Holder {
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
        address creator;
        address owner;
        uint256 balance;
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
        IGodwokenNFT nft = IGodwokenNFT(_collection);
        nft.safeTransferFrom(msg.sender, address(this), _token_id);
        // Create new pair item
        currentID = currentID.add(1);
        Pair memory item;
        item.pair_id = currentID;
        item.collection = _collection;
        item.token_id = _token_id;
        item.creator = getNFTCreator(_collection, _token_id);
        item.owner = msg.sender;
        item.price = _price;
        item.bValid = true;
        pairs[currentID] = item;
        emit ItemListed(item);
    }

    function delist(uint256 _id) external {
        require(pairs[_id].bValid && msg.sender == pairs[_id].owner, "Unauthorized owner");
        IGodwokenNFT(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pairs[_id].token_id);
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

        uint256 nftRoyalty = getRoyalty(pairs[_id].collection);
        address collection_owner = getCollectionOwner(pairs[_id].collection);
        uint256 nftRoyalties = getRoyalties(pairs[_id].collection, pairs[_id].token_id);
        address itemCreator = getNFTCreator(pairs[_id].collection, pairs[_id].token_id);
        
        uint256 feeAmount = totalAmount.mul(swapFee).div(PERCENTS_DIVIDER);
        uint256 royaltyAmount = totalAmount.mul(nftRoyalty).div(PERCENTS_DIVIDER);
        uint256 royaltiesAmount = totalAmount.mul(nftRoyalties).div(PERCENTS_DIVIDER);
        uint256 sellerAmount = totalAmount.sub(feeAmount).sub(royaltyAmount).sub(royaltiesAmount);
        if(swapFee > 0) {
            (bool fs, ) = payable(swapFeeAddress).call{value: feeAmount}("");
            require(fs, "Failed to send fee to fee address");
        }
        if(nftRoyalty > 0 && collection_owner != address(0x0)) {
            (bool hs, ) = payable(collection_owner).call{value: royaltyAmount}("");
            require(hs, "Failed to send collection royalty to collection owner");
        }
        if(nftRoyalties > 0 && itemCreator != address(0x0)) {
            (bool ps, ) = payable(itemCreator).call{value: royaltiesAmount}("");
            require(ps, "Failed to send item royalties to item creator");
        }
        (bool os, ) = payable(pair.owner).call{value: sellerAmount}("");
        require(os, "Failed to send to item owner"); 
        
        // transfer NFT token to buyer
        IGodwokenNFT(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.token_id);
        pairs[_id].bValid = false;

        emit Swapped(msg.sender, pair);
    }

    function getRoyalty(address collection) view internal returns(uint256) {
        IGodwokenNFT nft = IGodwokenNFT(collection);
        try nft.royalty() returns (uint256 value) {
            return value;
        } catch {
            return 0;
        }
    }

    function getRoyalties(address collection, uint256 tokenId) view internal returns(uint256) {
        IGodwokenNFT nft = IGodwokenNFT(collection);
        try nft.royalties(tokenId) returns (uint256 value) {
            return value;
        } catch {
            return 0;
        }
    }

    function getNFTCreator(address collection, uint256 tokenId) view internal returns(address) {
        IGodwokenNFT nft = IGodwokenNFT(collection); 
        try nft.creatorOf(tokenId) returns (address creatorAddress) {
            return creatorAddress;
        } catch {
            return address(0x0);
        }
    }

    function getCollectionOwner(address collection) view internal returns(address) {
        IGodwokenNFT nft = IGodwokenNFT(collection); 
        try nft.collectionOwner() returns (address collection_owner) {
            return collection_owner;
        } catch {
            return address(0x0);
        }
    }
}
