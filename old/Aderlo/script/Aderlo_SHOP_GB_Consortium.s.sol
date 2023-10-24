// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Aderlo_SHOP_GB_Consortium.sol";

contract Aderlo_SHOP_GB_Consortium is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        string memory baseURI = "ipfs://bafybeidvubye6v7tvjok6xan7ndofxqhiao7dtiqcyf6lowpd3sdubpday/";
        string memory name = "Aderlo SHOP GB Consortium";
        string memory symbol = "GBConsortium";
        uint32 totalSupply = 1000;
        uint256 cost = 10000000000000;
        bool open = true;
        NFTArtGenBase nft = new NFTArtGenBase(baseURI, name, symbol, totalSupply, cost, open);
        vm.stopBroadcast();
    }
}