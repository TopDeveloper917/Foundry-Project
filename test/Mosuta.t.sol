// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "@std/Test.sol";

import {Monsuta, ERC721AQueryable, ERC721, IERC20, Address} from "../src/Monsuta.sol";
import {MonsutaRegistry} from "../src/MonsutaRegistry.sol";
import {FAVOR} from "../src/FAVOR.sol";

contract MonsutaTest is Test {
    Monsuta monsuta;
    FAVOR favor;
    MonsutaRegistry registry;

    /// @dev The Monsuta owner
    address public constant OWNER = address(1337);

    uint256 startSaleTimestamp = 1617580800;

    /// @notice Sets up the testing suite
    function setUp() public {
        vm.warp(startSaleTimestamp - 1);
        startHoax(OWNER, OWNER, type(uint256).max);
        monsuta = new Monsuta("Monsuta", "Monsuta");
        favor = new FAVOR(address(monsuta));
        registry = new MonsutaRegistry(address(monsuta));

        monsuta.setFavor(address(favor));
        monsuta.setRegistry(address(registry));
        vm.stopPrank();

        // Validate Monsuta Metadata and Ownership
        assert(OWNER == monsuta.owner());
        assert(
            keccak256(abi.encodePacked("Monsuta")) ==
                keccak256(abi.encodePacked(monsuta.name()))
        );
        assert(
            keccak256(abi.encodePacked("Monsuta")) ==
                keccak256(abi.encodePacked(monsuta.symbol()))
        );

        assert(monsuta.emissionStart() == startSaleTimestamp);
        assert(
            monsuta.emissionEnd() == startSaleTimestamp + (86400 * 365 * 10)
        );
    }

    /// @notice Allows anyone to mint tokens after the start time
    function testMinting(address alice) public {
        vm.assume(alice != address(0));
        vm.assume(!Address.isContract(alice));

        uint256 MINT_PRICE = monsuta.getMintPrice();

        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert("not started");
        monsuta.mint(1);
        vm.stopPrank();

        vm.warp(startSaleTimestamp);
        // Enable minting from the owner
        startHoax(OWNER, OWNER, 0);
        monsuta.toggleSale();
        vm.expectRevert("Sale is paused");
        monsuta.mint(1);
        monsuta.toggleSale();
        vm.stopPrank();

        // Minter still can't mint if they don't supply the required payment
        startHoax(alice, alice, type(uint256).max);
        vm.expectRevert("Ether value sent is not correct");
        monsuta.mint{value: 0.0001 ether}(2);
        vm.stopPrank();

        // Minter can mint if they supply the required payment
        startHoax(alice, alice, MINT_PRICE);
        monsuta.mint{value: MINT_PRICE}(1);
        assert(alice.balance == 0);
        assert(monsuta.ownerOf(0) == alice);
        assert(monsuta.balanceOf(alice) == 1);
        assert(monsuta.getLastClaim(0) == startSaleTimestamp);
        vm.stopPrank();

        // // But can mint 1 more
        // // Minter can mint if they supply the required payment
        startHoax(alice, alice, MINT_PRICE);
        monsuta.mint{value: MINT_PRICE}(1);
        assert(alice.balance == 0);
        assert(monsuta.balanceOf(alice) == 2);
        vm.stopPrank();

        // // Can't mint more than 20
        startHoax(alice, alice, MINT_PRICE * 21);
        vm.expectRevert("invalid numberOfNfts");
        monsuta.mint{value: MINT_PRICE * 21}(21);
        vm.stopPrank();

        // // Owner can disable minting
        startHoax(OWNER, OWNER, 0);
        monsuta.toggleSale();
        vm.stopPrank();

        // // Minting should be disabled now
        startHoax(alice, alice, MINT_PRICE * 2);
        vm.expectRevert("Sale is paused");
        monsuta.mint{value: MINT_PRICE * 0}(2);
        vm.stopPrank();
    }

    function testFavorRewards(address alice) public {
        vm.assume(alice != address(0));
        vm.assume(!Address.isContract(alice));
        vm.warp(startSaleTimestamp);

        uint256 MINT_PRICE = monsuta.getMintPrice();
        uint256 emissionPerDay = monsuta.emissionPerDay();

        // Mint & update rewards
        startHoax(alice, alice, type(uint256).max);
        monsuta.mint{value: MINT_PRICE}(1);
        assert(monsuta.ownerOf(0) == alice);
        assert(monsuta.balanceOf(alice) == 1);
        assert(monsuta.getLastClaim(0) == startSaleTimestamp);
        assert(monsuta.getAccumulated(0) == 0);

        vm.warp(startSaleTimestamp + 100);
        assert(monsuta.getLastClaim(0) == startSaleTimestamp);

        uint256 totalAccumulated = (100 *
            emissionPerDay *
            monsuta.multiplierFromState(0)) /
            86400 +
            monsuta.INITIAL_ALLOTMENT();
        assert(monsuta.getAccumulated(0) == totalAccumulated);

        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;

        monsuta.claim(ids);
        assert(favor.balanceOf(alice) == totalAccumulated);

        assert(monsuta.getLastClaim(0) == block.timestamp);
        assert(monsuta.getAccumulated(0) == 0);

        monsuta.mint{value: MINT_PRICE}(1);
        assert(monsuta.ownerOf(1) == alice);
        assert(monsuta.balanceOf(alice) == 2);
        assert(monsuta.getLastClaim(1) == startSaleTimestamp);
        assert(monsuta.getAccumulated(1) == totalAccumulated);

        uint256[] memory ownTokenIds = monsuta.tokensOfOwner(alice);
        emit log_uint(ownTokenIds.length);

        assert(monsuta.getAccumulatedAll(alice) == totalAccumulated);
        monsuta.claimAll();
        assert(favor.balanceOf(alice) == totalAccumulated * 2);

        vm.stopPrank();
    }

    function testTransfer(address alice, address bob) public {
        vm.assume(alice != address(0));
        vm.assume(!Address.isContract(alice));

        vm.assume(bob != address(0));
        vm.assume(!Address.isContract(bob));
        vm.assume(alice != bob);

        vm.warp(startSaleTimestamp);

        uint256 MINT_PRICE = monsuta.getMintPrice();
        uint256 emissionPerDay = monsuta.emissionPerDay();

        // Mint & update rewards
        startHoax(alice, alice, type(uint256).max);
        monsuta.mint{value: MINT_PRICE}(1);
        assert(monsuta.ownerOf(0) == alice);
        assert(monsuta.balanceOf(alice) == 1);
        assert(monsuta.getLastClaim(0) == startSaleTimestamp);
        assert(monsuta.getAccumulated(0) == 0);

        vm.warp(startSaleTimestamp + 100);

        uint256 totalAccumulated = (100 *
            emissionPerDay *
            monsuta.multiplierFromState(0)) /
            86400 +
            monsuta.INITIAL_ALLOTMENT();
        assert(monsuta.getAccumulated(0) == totalAccumulated);

        monsuta.safeTransferFrom(alice, bob, 0, "");

        // before transfer update rewards called
        assert(favor.balanceOf(alice) == totalAccumulated);

        assert(monsuta.ownerOf(0) == bob);
        assert(monsuta.balanceOf(bob) == 1);
        assert(monsuta.balanceOf(alice) == 0);
        assert(monsuta.getLastClaim(0) == block.timestamp);
        assert(monsuta.getAccumulated(0) == 0);

        vm.stopPrank();
    }

    function testTokenURI() public {
        address alice = address(1);
        vm.warp(startSaleTimestamp);
        vm.roll(100);

        uint256 MINT_PRICE = monsuta.getMintPrice();

        // Mint & update rewards
        startHoax(alice, alice, type(uint256).max);
        monsuta.mint{value: MINT_PRICE * 20}(20);
        assert(monsuta.ownerOf(0) == alice);
        assert(monsuta.balanceOf(alice) == 20);

        // check tokenURI before reveal
        string memory uri = monsuta.tokenURI(3);
        emit log_named_string("token uri #3 before reveal", uri);

        vm.warp(startSaleTimestamp + 86400 * 14);
        vm.roll(400);

        monsuta.mint{value: MINT_PRICE * 1}(1);

        assert(monsuta.startingIndexBlock() == block.number);

        vm.roll(500);
        monsuta.finalizeStartingIndex();
        uint256 startingIndex = monsuta.startingIndex();

        vm.stopPrank();

        // if reveal time passed, can call reveal
        startHoax(OWNER, OWNER, 0);

        // reveal
        registry.reveal();
        assert(registry.startingIndexFromMonsutaContract() == startingIndex);

        // upload metadata
        bytes4[] memory traitsHex = new bytes4[](10);
        traitsHex[0] = 0x0011010F;
        traitsHex[1] = 0x0012010F;
        traitsHex[2] = 0x00311121;
        traitsHex[3] = 0x0110230F;
        traitsHex[4] = 0x01112112;

        registry.storeMetadataStartingAtIndex(0, traitsHex);

        assert(registry.getTraitBytesAtIndex(0) == traitsHex[0]);

        vm.stopPrank();

        // check tokenURI after reveal
        // uri = monsuta.tokenURI(monsuta.MAX_NFT_SUPPLY() - startingIndex + 3);
        // emit log_named_string("token uri #3 after reveal", uri);
    }

    function testChangeName() public {
        address alice = address(1);
        vm.warp(startSaleTimestamp + 1);
        uint256 MINT_PRICE = monsuta.getMintPrice();

        // Mint & update rewards
        startHoax(alice, alice, type(uint256).max);
        monsuta.mint{value: MINT_PRICE * 20}(20);
        assert(monsuta.ownerOf(0) == alice);
        assert(monsuta.balanceOf(alice) == 20);

        monsuta.claimAll();

        favor.approve(address(monsuta), monsuta.nameChangePrice());

        uint256 favorBalance1 = favor.balanceOf(alice);

        string memory newname1 = "xxnewname";
        monsuta.changeName(0, newname1);

        assert(monsuta.isNameReserved(newname1));
        assert(
            keccak256(abi.encodePacked(newname1)) ==
                keccak256(abi.encodePacked(monsuta.tokenNameByIndex(0)))
        );
        assert(
            favor.balanceOf(alice) == favorBalance1 - monsuta.nameChangePrice()
        );

        vm.expectRevert("same as the current one");
        monsuta.changeName(0, newname1);

        vm.expectRevert("already reserved");
        monsuta.changeName(1, newname1);

        vm.stopPrank();
    }

    function testSacrificeResurrect() public {
        address alice = address(1);
        vm.warp(startSaleTimestamp + 1);
        uint256 MINT_PRICE = monsuta.getMintPrice();

        // Mint & update rewards
        startHoax(alice, alice, type(uint256).max);
        monsuta.mint{value: MINT_PRICE * 20}(20);
        assert(monsuta.ownerOf(0) == alice);
        assert(monsuta.balanceOf(alice) == 20);

        monsuta.claimAll();

        favor.approve(address(monsuta), monsuta.sacrificePrice());

        uint256 favorBalance1 = favor.balanceOf(alice);

        // sacrifice
        monsuta.sacrifice(0, 1);

        assert(monsuta.getTokenState(0) == 1);
        assert(monsuta.getTokenState(1) == 2);
        assert(
            favor.balanceOf(alice) == favorBalance1 - monsuta.sacrificePrice()
        );

        vm.expectRevert("!evolving item default");
        monsuta.sacrifice(0, 1);

        vm.expectRevert("!soul item default");
        monsuta.sacrifice(2, 1);

        // resurrect
        favorBalance1 = favor.balanceOf(alice);

        favor.approve(address(monsuta), monsuta.resurrectPrice());

        monsuta.resurrect(0, 1);
        assert(monsuta.getTokenState(0) == 0);
        assert(monsuta.getTokenState(1) == 0);
        assert(
            favor.balanceOf(alice) == favorBalance1 - monsuta.resurrectPrice()
        );
        vm.stopPrank();
    }

    function testTrade() public {
        address alice = address(1);
        address bob = address(2);

        vm.warp(startSaleTimestamp + 1);
        uint256 MINT_PRICE = monsuta.getMintPrice();

        // Mint & update rewards
        startHoax(alice, alice, type(uint256).max);
        monsuta.mint{value: MINT_PRICE * 1}(1);
        assert(monsuta.ownerOf(0) == alice);
        assert(monsuta.balanceOf(alice) == 1);
        vm.stopPrank();

        startHoax(bob, bob, type(uint256).max);
        monsuta.mint{value: MINT_PRICE * 1}(1);
        assert(monsuta.ownerOf(1) == bob);
        assert(monsuta.balanceOf(bob) == 1);

        // open trade
        uint256 expireDate = startSaleTimestamp + 10;
        monsuta.openNewTrade(1, 0, expireDate);

        assert(monsuta.getTradeCount() == 1);
        assert(monsuta.isTradeExecutable(0));

        vm.stopPrank();

        // execute
        vm.startPrank(alice);
        monsuta.executeTrade(0);
        assert(monsuta.isTradeExecutable(0) == false);
        assert(monsuta.ownerOf(0) == bob);
        assert(monsuta.ownerOf(1) == alice);
        vm.stopPrank();

        // cancel
        vm.startPrank(alice);
        assert(monsuta.ownerOf(0) == bob);
        assert(monsuta.ownerOf(1) == alice);

        monsuta.openNewTrade(1, 0, expireDate);
        monsuta.cancelTrade(1);
        vm.stopPrank();
    }
}
