// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../custom-lib/Auth.sol";

contract FraArtAuction is Auth, ERC721Holder {
    using SafeMath for uint256;
    using Address for address;

    uint256 constant public PERCENTS_DIVIDER = 1000;
    uint256 constant public MIN_BID_INCREMENT_PERCENT = 50; // 5%
    uint256 public swapFee = 25;  // 2.5% for admin tx fee
    address public swapFeeAddress;
    
    // Bid struct to hold bidder and amount
    struct Bid {
        address from;
        uint256 bidPrice;
    }

    // Auction struct which holds all the required info
    struct Auction {
        uint256 auction_id;
        address collection;
        uint256 token_id;
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        address owner;
        bool active;
    }
    uint256 public currentID;
    // Array with all auctions
    mapping(uint256 => Auction) public auctions;
    // Mapping from auction index to user bids
    mapping (uint256 => Bid[]) public auctionBids;

    event BidSuccess(address _from, uint256 _auctionId, uint256 _amount, uint256 _bidIndex);
    // AuctionCreated is fired when an auction is created
    event AuctionCreated(Auction auction);
    // AuctionCanceled is fired when an auction is canceled
    event AuctionCanceled(uint _auctionId);
    // AuctionFinalized is fired when an auction is finalized
    event AuctionFinalized(Bid bid, Auction auction);

    constructor () Auth(msg.sender) { swapFeeAddress = msg.sender; }

    function setFee(uint256 _swapFee, address _swapFeeAddress) external authorized {
        swapFee = _swapFee;
        swapFeeAddress = _swapFeeAddress;
    }

    function createAuction(
        address _collection, 
        uint256 _token_id, 
        uint256 _startPrice, 
        uint256 _startTime, 
        uint256 _endTime
    ) OnlyItemOwner(_collection, _token_id) public {
        require(block.timestamp < _endTime, "end timestamp have to be bigger than current time");
        IERC721 nft = IERC721(_collection);
        nft.safeTransferFrom(msg.sender, address(this), _token_id);

        currentID = currentID.add(1);
        Auction memory newAuction;
        newAuction.auction_id = currentID;
        newAuction.collection = _collection;
        newAuction.token_id = _token_id;
        newAuction.startPrice = _startPrice;
        newAuction.startTime = _startTime;
        newAuction.endTime = _endTime;
        newAuction.owner = msg.sender;
        newAuction.active = true;
        auctions[currentID] = newAuction;
        emit AuctionCreated(newAuction);
    }
    
    function finalizeAuction(uint256 _auction_id) public {
        require(_auction_id <= currentID && auctions[_auction_id].active, "Invalid Auction Id");
        Auction memory myAuction = auctions[_auction_id];
        uint256 bidsLength = auctionBids[_auction_id].length;
        require(msg.sender == myAuction.owner, "only auction owner can finalize");
        // if there are no bids cancel
        if (bidsLength == 0) {
            IERC721(myAuction.collection).safeTransferFrom(address(this), myAuction.owner, myAuction.token_id);
            auctions[_auction_id].active = false;
            emit AuctionCanceled(_auction_id);
        } else {
            // the money goes to the auction owner
            Bid memory lastBid = auctionBids[_auction_id][bidsLength - 1];

            uint256 feeAmount = lastBid.bidPrice.mul(swapFee).div(PERCENTS_DIVIDER);
            uint256 sellerAmount = lastBid.bidPrice.sub(feeAmount);
            if(swapFee > 0) {
                (bool fs, ) = payable(swapFeeAddress).call{value: feeAmount}("");
                require(fs, "Failed to send fee to fee address");
            }
            (bool os, ) = payable(myAuction.owner).call{value: sellerAmount}("");
            require(os, "Failed to send to item owner");

            IERC721(myAuction.collection).safeTransferFrom(address(this), lastBid.from, myAuction.token_id);
            auctions[_auction_id].active = false;
            emit AuctionFinalized(lastBid, myAuction);
        }
    }
    
    function bidOnAuction(uint256 _auction_id, uint256 amount) external payable {
        require(_auction_id <= currentID && auctions[_auction_id].active, "Invalid Auction Id");
        Auction memory myAuction = auctions[_auction_id];
        require(myAuction.owner != msg.sender, "Owner can not bid");
        require(block.timestamp < myAuction.endTime, "auction is over");
        require(block.timestamp >= myAuction.startTime, "auction is not started");

        uint256 bidsLength = auctionBids[_auction_id].length;
        uint256 tempAmount = myAuction.startPrice;
        Bid memory lastBid;
        if( bidsLength > 0 ) {
            lastBid = auctionBids[_auction_id][bidsLength - 1];
            tempAmount = lastBid.bidPrice.mul(PERCENTS_DIVIDER + MIN_BID_INCREMENT_PERCENT).div(PERCENTS_DIVIDER);
        }
        require(msg.value >= tempAmount, "too small amount");
        require(msg.value >= amount, "too small balance");
        if( bidsLength > 0 ) {
            (bool result, ) = payable(lastBid.from).call{value: lastBid.bidPrice}("");
            require(result, "Failed to send to the last bidder!");
        }

        Bid memory newBid;
        newBid.from = msg.sender;
        newBid.bidPrice = amount;
        auctionBids[_auction_id].push(newBid);
        emit BidSuccess(msg.sender, _auction_id, newBid.bidPrice, bidsLength);
    }
    
    function getBidsAmount(uint256 _auction_id) public view returns(uint) {
        return auctionBids[_auction_id].length;
    }
    
    function getCurrentBids(uint256 _auction_id) public view returns(uint256, address) {
        uint256 bidsLength = auctionBids[_auction_id].length;
        // if there are bids refund the last bid
        if (bidsLength >= 0) {
            Bid memory lastBid = auctionBids[_auction_id][bidsLength - 1];
            return (lastBid.bidPrice, lastBid.from);
        }    
        return (0, address(0));
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