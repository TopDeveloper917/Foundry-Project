// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Aderlo_SHOP_Dubai_Mall_Consortium.sol";

contract Aderlo_SHOP_Dubai_Mall_Consortium is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory baseURI = "ipfs://bafybeiet7nqknaevdzg3jmin5urvwauuujshexsjho5szylbtl2lg2rwui/";
        string memory name = "Aderlo SHOP Dubai Mall Consortium";
        string memory symbol = "SHOP Dubai";
        uint32 totalSupply = 1000;
        uint256 cost = 10000000000000;
        bool open = true;
        NFTArtGenBase nft = new NFTArtGenBase(baseURI, name, symbol, totalSupply, cost, open);
        vm.stopBroadcast();
    }
}