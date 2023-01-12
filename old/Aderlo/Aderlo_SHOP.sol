// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Consecutive.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @custom:security-contact contact@parlour.dev
contract AderloShop is ERC721Enumerable, ERC2981, Ownable {
    using Strings for uint256;

    constructor() ERC721("Aderlo SHOP", "SHOP") Ownable() {
        _setDefaultRoyalty(msg.sender, 700);
        for (uint256 i = 1; i <= 9; i++) {  // 39
            _mint(0xBB97a6BEbbECCD1617e7b402AAE9E9688E1C98F8, i);  // 0x0c13e4eA3E2fbb26E386BCdfd3FcbDfeEc607A8c
        }
    }

    function updateOwnership() external onlyOwner {
        _setDefaultRoyalty(owner(), 700);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://xvrm.parlour.construction/shop/";
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
                : "";
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