// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Aderlo_Metaverse_PREMIUM_Club.sol";

contract Aderlo_Metaverse_PREMIUM_Club is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AderloMetaversePremiumClub nft = new AderloMetaversePremiumClub();
        vm.stopBroadcast();
    }
}
