// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Aderlus_PL.sol";

contract Aderlus_PL is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory baseURI = "ipfs://QmfJUavTydFBQhbruAQmojsFUNPKfqtZ5YUTDmvXmTVWCF/";
        string memory name = "Aderlus PL";
        string memory symbol = "ADERLUSPL";
        uint32 totalSupply = 1000;
        uint256 cost = 10000000000000;
        bool open = true;
        NFTArtGenBase nft = new NFTArtGenBase(baseURI, name, symbol, totalSupply, cost, open);
        vm.stopBroadcast();
    }
}