// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Aderlo_SHOP_Great_Britain.sol";

contract Aderlo_SHOP_Great_Britain is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        string memory baseURI = "ipfs://bafybeib3jvlkxt6nnvqvmkfa4kf47nshu2lhbhahe4pdtrnx5i34khfca4/";
        string memory name = "Aderlo SHOP Great Britain";
        string memory symbol = "SHOP";
        uint32 totalSupply = 1000;
        uint256 cost = 10000000000000;
        bool open = true;
        NFTArtGenBase nft = new NFTArtGenBase(baseURI, name, symbol, totalSupply, cost, open);
        vm.stopBroadcast();
    }
}