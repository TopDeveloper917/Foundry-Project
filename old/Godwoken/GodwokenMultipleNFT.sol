// Multiple NFTMania token
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GodwokenMultipleNFT is ERC1155, AccessControl {
    using SafeMath for uint256;

    struct Item {
        uint256 id;
        address creator;
        string uri;
        uint256 supply;
        uint256 royaltyItem;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public constant PERCENTS_DIVIDER = 1000;
	uint256 constant public FEE_MAX_PERCENT = 500; // 50 %
    uint256 constant public FEE_MIN_PERCENT = 50; // 5 %

    string public collection_name;
    string public collection_symbol;
    string public collection_uri;
    uint256 public collection_royalty;
    bool public isPublic;
    address public factory;
    address public collection_owner;

    uint256 public currentID;
    mapping (uint256 => Item) public Items;

    event CollectionUriUpdated(string collection_uri);
    event CollectionNameUpdated(string collection_name);
    event CollectionSymbolUpdated(string collectionSymbol);
    event CollectionRoyaltyUpdated(uint256 collectionRoyalty);
    event CollectionPublicUpdated(bool isPublic);
    event CollectionOwnerUpdated(address newOwner);
    event TokenUriUpdated(uint256 id, string uri);
    event MultipleItemCreated(Item item);

    constructor() ERC1155("") {
        factory = msg.sender;
    }
    /**
		Get Collection Info
	 */
    function contractURI() external view returns (string memory) {
        return collection_uri;
    }

    function name() public view virtual returns (string memory) {
        return collection_name;
    }

    function symbol() public view virtual returns (string memory) {
        return collection_symbol;
    }

    function royalty() public view virtual returns (uint256) {
        return collection_royalty;
    }

    function collectionOwner() public view virtual returns (address) {
        return collection_owner;
    }

    function uri(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        bytes memory customUriBytes = bytes(Items[_tokenId].uri);
        if (customUriBytes.length > 0) {
            return Items[_tokenId].uri;
        } else {
            return super.uri(_tokenId);
        }
    }

    function totalSupply() public view virtual returns (uint256) {
        return currentID;
    }

    function tokenSupply(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        return Items[_tokenId].supply;
    }

    function royalties(uint256 _tokenId) public view returns (uint256) {
        return Items[_tokenId].royaltyItem;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
		Initialize from Swap contract
	 */
    function initialize(string memory _name, string memory _symbol, string memory _uri, address _creator, uint256 _royalty, bool _isPublic ) external {
        require(msg.sender == factory, "Only for factory");
        _setURI(_uri);
        collection_name = _name;
        collection_symbol = _symbol;
        collection_royalty = _royalty;
        collection_owner = _creator;
        isPublic = _isPublic;

        _setupRole(DEFAULT_ADMIN_ROLE, _creator);
        _setupRole(MINTER_ROLE, _creator);
    }

    /**
		Change Collection Info
	 */
    function setCollectionURI(string memory newURI) external contractOwner {
        collection_uri = newURI;
        emit CollectionUriUpdated(newURI);
    }

    function setName(string memory newname) external contractOwner {
        collection_name = newname;
        emit CollectionNameUpdated(newname);
    }

    function setSymbol(string memory newname) external contractOwner {
        collection_symbol = newname;
        emit CollectionSymbolUpdated(newname);
    }

    function setRoyalty(uint256 _newRoyalty) external contractOwner {
        collection_royalty = _newRoyalty;
        emit CollectionRoyaltyUpdated(_newRoyalty);
    }

    function setPublic(bool bPublic) external contractOwner {
        isPublic = bPublic;
        emit CollectionPublicUpdated(isPublic);
    }

    function setCustomURI(uint256 _tokenId, string memory _newURI) public creatorOnly(_tokenId) {
        Items[_tokenId].uri = _newURI;
        emit TokenUriUpdated(_tokenId, _newURI);
    }

    function addItem( uint256 _supply, uint256 _royalty, string memory _uri ) public returns (uint256) {
        require( hasRole(MINTER_ROLE, msg.sender) || isPublic, "Only minter can add item");
        require(_supply > 0, "Supply can not be zero");
        require(_royalty <= FEE_MAX_PERCENT, "Too big royalties");
        require(_royalty >= FEE_MIN_PERCENT, "Too small royalties");
        
        currentID = currentID.add(1);
        _mint(msg.sender, currentID, _supply, "MINT");

        Items[currentID] = Item(currentID, msg.sender, _uri, _supply, _royalty);
        emit MultipleItemCreated(Items[currentID]);
        return currentID;
    }

    function burn(address _from, uint256 _tokenId, uint256 _amount) public returns(bool){
		uint256 nft_token_balance = balanceOf(msg.sender, _tokenId);
		require(nft_token_balance > 0, "Only owner can burn");
        require(nft_token_balance >= _amount, "Invalid amount : amount have to be smaller than the balance");
		_burn(_from, _tokenId, _amount);
        Items[_tokenId].supply = Items[_tokenId].supply - _amount;
		return true;
	}

    function creatorOf(uint256 _tokenId) public view returns (address) {
        return Items[_tokenId].creator;
    }

    modifier contractOwner() {
        require(collection_owner == _msgSender(), "The caller is unauthorized!");
        _;
    }

    modifier creatorOnly(uint256 _id) {
        require(
            Items[_id].creator == _msgSender(),
            "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED"
        );
        _;
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return _id <= currentID;
    }

    function transferCreator(address _newOwner) external contractOwner {
        collection_owner = _newOwner;
        emit CollectionOwnerUpdated(_newOwner);
    }
}
