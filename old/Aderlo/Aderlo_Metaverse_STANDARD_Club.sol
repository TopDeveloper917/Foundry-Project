// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @custom:security-contact contact@parlour.dev
contract AderloMetaverseStandardClub is ERC721Enumerable, ERC2981, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256 public price = 0.5 ether;

    constructor() ERC721("Aderlo Metaverse STANDARD Club", "AMSC") Ownable() {
        _setDefaultRoyalty(msg.sender, 700);
        for (uint256 i = 1; i <= 10; i++) {  // 200
            _mint(0xBB97a6BEbbECCD1617e7b402AAE9E9688E1C98F8, i);  // 0x0c13e4eA3E2fbb26E386BCdfd3FcbDfeEc607A8c
        }
    }

    // **********************************************************
    // ************************   SALE   ************************
    // **********************************************************

    function buy() external payable {
        require(msg.value >= price, "Not enough BNB");
        _internalMint(msg.sender);
    }

    function changePrice(uint256 _price) external onlyOwner {
        price = _price;
    }

    // **********************************************************
    // ************************ MINTING  ************************
    // **********************************************************

    function premintExtraBatch() external onlyOwner {
        for (uint256 i = 201; i <= 350; i++) {
            _mint(0xBB97a6BEbbECCD1617e7b402AAE9E9688E1C98F8, i);  // 0x0c13e4eA3E2fbb26E386BCdfd3FcbDfeEc607A8c
        }
    }

    function _internalMint(address to) internal {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current() + 350;

        require(totalSupply() < 1000, "AMSC: Max supply reached 1");
        require(tokenId <= 1000, "AMSC: Max supply reached 2");

        _safeMint(to, tokenId);
    }

    // **********************************************************
    // ************************ PLUMBING ************************
    // **********************************************************

    function updateOwnership() external onlyOwner {
        _setDefaultRoyalty(owner(), 700);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://xvrm.parlour.construction/amsc/";
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        uint256 internalJSONId = tokenId % 3;
        return
            string(
                abi.encodePacked(baseURI, internalJSONId.toString(), ".json")
            );
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}