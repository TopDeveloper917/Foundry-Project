// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Aderlo_SHOP_PL_Consortium.sol";

contract Aderlo_SHOP_PL_Consortium is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory baseURI = "ipfs://QmWxB6WNvAVy6QB1QGUDuWT99opGP3ximhQA4CN6esK1Cm/";
        string memory name = "Aderlo SHOP PL Consortium";
        string memory symbol = "ADERLOPL";
        uint32 totalSupply = 1000;
        uint256 cost = 10000000000000;
        bool open = true;
        NFTArtGenBase nft = new NFTArtGenBase(baseURI, name, symbol, totalSupply, cost, open);
        vm.stopBroadcast();
    }
}