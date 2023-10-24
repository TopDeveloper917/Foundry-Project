// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Aderlo_SHOP_The_Dubai_Mall.sol";

contract Aderlo_SHOP_The_Dubai_Mall is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory baseURI = "ipfs://bafybeig33mbgamax34volurep665hjdtmcnwcx5lxlxv5cuwjddqo3gy3y/";
        string memory name = "Aderlo SHOP The Dubai Mall";
        string memory symbol = "DUBMALL";
        uint32 totalSupply = 1000;
        uint256 cost = 10000000000000;
        bool open = true;
        NFTArtGenBase nft = new NFTArtGenBase(baseURI, name, symbol, totalSupply, cost, open);
        vm.stopBroadcast();
    }
}