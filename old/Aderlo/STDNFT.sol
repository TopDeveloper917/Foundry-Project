// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract STDNFT is ERC721 {
    using SafeMath for uint256;
    using Address for address;

    string collection_name;
    string collection_symbol;
    string collection_uri;
    uint256 collection_royalty;
    bool public isPublic;
    address public factory; // swap contract
    address collection_owner;
    string baseURI;

    struct Item {
        uint256 id;
        address creator;
        string uri;
        uint256 royaltyItem;
    }
    uint256 currentID;
    mapping (uint256 => Item) public Items;

    event CollectionUriUpdated(string collectionUri);
    event CollectionNameUpdated(string collectionName);
    event CollectionSymbolUpdated(string collectionSymbol);
    event CollectionBaseURIUpdated(string collectionBaseURI);
    event CollectionRoyaltyUpdated(uint256 collectionRoyalty);
    event CollectionPublicUpdated(bool isPublic);
    event CollectionOwnerUpdated(address newOwner);
    event ItemCreated(Item item);

    constructor() ERC721("","") {
        factory = msg.sender;
    }

    function contractURI() external view returns (string memory) {
        return collection_uri;
    }

    function name() public view virtual override returns (string memory) {
        return collection_name;
    }

    function symbol() public view virtual override returns (string memory) {
        return collection_symbol;
    }

    function royalty() public view virtual returns (uint256) {
        return collection_royalty;
    }

    function collectionOwner() public view virtual returns (address) {
        return collection_owner;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return Items[tokenId].uri;
    }

    function totalSupply() public view virtual returns (uint256) {
        return currentID;
    }

    function royalties(uint256 _tokenId) public view returns (uint256) {
        return Items[_tokenId].royaltyItem;
    }

    /**
        Initialize from Swap contract
     */
    function initialize(string memory _name, string memory _symbol, string memory _uri, address _creator, uint256 _royalty, bool _isPublic) external {
        require(msg.sender == factory, "Only for factory");
        collection_uri = _uri;
        collection_name = _name;
        collection_symbol = _symbol;
        collection_owner = _creator;
        collection_royalty = _royalty;
        isPublic = _isPublic;
    }
    
    /**
		Change & Get Collection Info
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

    function setBaseURI(string memory newBaseURI) external contractOwner {
        baseURI = newBaseURI;
        emit CollectionBaseURIUpdated(newBaseURI);
    }

    function setRoyalty(uint256 newRoyalty) external contractOwner {
        collection_royalty = newRoyalty;
        emit CollectionRoyaltyUpdated(newRoyalty);
    }

    function setPublic(bool bPublic) external contractOwner {
        isPublic = bPublic;
        emit CollectionPublicUpdated(isPublic);
    }

    function addItem(string memory _tokenURI, uint256 _royalty) external {
        require(_msgSender() == collection_owner || isPublic, "The minter is unauthorized!");
        currentID = currentID.add(1);
        _safeMint(msg.sender, currentID);
        Item memory item;
        item.id = currentID;
        item.creator = msg.sender;
        item.uri = _tokenURI;
        item.royaltyItem = _royalty;
        Items[currentID] = item;
        emit ItemCreated(item);
    }
    
    function creatorOf(uint256 _tokenId) public view returns (address) {
        return Items[_tokenId].creator;
    }
    modifier contractOwner() {
        require(collection_owner == _msgSender(), "The caller is unauthorized!");
        _;
    }
    // transfer collectoin owner
    function transferCreator(address _newOwner) external contractOwner {
        collection_owner = _newOwner;
        emit CollectionOwnerUpdated(_newOwner);
    }
    // update factor
    function updateFactory(address _factory) public {
        require(msg.sender == factory, "Factory can be updated by previous factory!");
        factory = _factory;
    }
}