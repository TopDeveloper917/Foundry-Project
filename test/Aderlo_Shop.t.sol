// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {AderloShop} from "../src/Aderlo_SHOP.sol";

contract Aderlo_ShopTest is Test {
    AderloShop aderloShop;
    /// @dev The shop owner
    address public constant OWNER = address(999);
    
}