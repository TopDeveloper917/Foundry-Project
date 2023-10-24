// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../custom-lib/SafeERC721.sol";
import "../custom-lib/Auth.sol";

contract FraArtBoxes is Auth, ERC721Holder, ERC721, ReentrancyGuard {
    using SafeERC721 for IERC721;

    struct Item {
        address collection;
        uint256 tokenId;
    }

    struct Box {
        uint256 box_id;
        string uri;
    }
    uint256 public boxIndex = 0;
    // box_id => items (one box has several NFTs)
    mapping(uint256 => Item[]) private _items;
    // One Box is one ERC721 token for fractions
    mapping(uint256 => Box) private _boxes;

    event TokenUriUpdated(uint256 id, string uri);

    constructor () ERC721("Boxes", "BOX") Auth(msg.sender) {}

    function tokenURI(uint256 boxId) public view override returns (string memory) {
        require(boxId <= boxIndex, "ERC721Metadata: URI query for nonexistent token");
        return _boxes[boxId].uri;
    }

    function setTokenURI(uint256 _boxId, string memory _cid) public onlyOperator(_boxId) {
        _boxes[_boxId].uri = _cid;
        emit TokenUriUpdated( _boxId, _cid);
    }

    function addBox(address[] memory _collections, uint256[] memory _tokenIds, string[] memory _cids) external nonReentrant returns (uint256 _boxId) {
        require(_collections.length == _tokenIds.length && _collections.length == _cids.length, "length mismatch");
        for (uint256 i = 0; i < _collections.length; i++) {
            IERC721(_collections[i]).safeTransferFrom(msg.sender, address(this), _tokenIds[i], "Send to box");
        }
        
    }

    modifier onlyOperator(uint256 _boxId) {
        require(isAuthorized(_msgSender()) || ownerOf(_boxId) == _msgSender(), "The caller is not an operator");
        _;
    }
}