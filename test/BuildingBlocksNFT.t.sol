// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.14;

import "../src/BuildingBlocksNFT.sol";
import "forge-std/Test.sol";

contract BuildingBlocksNFTTest is Test {
    uint256 constant MAX_SUPPLY = 10;
    uint256 constant RESERVED_SUPPLY = 0;
    uint256 constant MINTABLE_SUPPLY = MAX_SUPPLY - RESERVED_SUPPLY;
    uint256 constant EXCLUSIVE_WHITELIST_MINT_PRICE = 0.08 ether;
    uint256 constant WHITELIST_MINT_PRICE = 0.09 ether;
    uint256 constant PUBLIC_MINT_PRICE = 0.1 ether;
    uint256 constant DIVIDENDS_SHARE_BP = 1000;
    uint96 constant ROYALTY_BP = 2e3;
    uint256 constant DIVIDENDS_ROYALTY_SHARES = 8;
    uint256 constant PROJECT_ROYALTY_SHARES = 2;

    address projectTreasury = address(1);
    address dividendsTreasury = address(2);
    address alice = address(3);

    BuildingBlocksNFT nft;

    function setUp() public {
        nft = new BuildingBlocksNFT(
            BuildingBlocksNFT.BuildingBlocksConfig({
                name: "name",
                symbol: "symbol",
                maxSupply: MAX_SUPPLY,
                reservedSupply: RESERVED_SUPPLY,
                exclusiveWhitelistMintPrice: EXCLUSIVE_WHITELIST_MINT_PRICE,
                whitelistMintPrice: WHITELIST_MINT_PRICE,
                publicMintPrice: PUBLIC_MINT_PRICE,
                dividendsTreasury: dividendsTreasury,
                projectTreasury: projectTreasury,
                dividendsShareBasisPoints: DIVIDENDS_SHARE_BP,
                royaltyBasisPoints: ROYALTY_BP,
                dividendsRoyaltyShares: DIVIDENDS_ROYALTY_SHARES,
                projectRoyaltyShares: PROJECT_ROYALTY_SHARES,
                mintingStartTimestamp: block.timestamp
            })
        );

        vm.label(address(this), "Owner");
        vm.label(projectTreasury, "ProjectTreasury");
        vm.label(dividendsTreasury, "DividendsTreasury");
        vm.label(alice, "Alice");
        vm.label(address(nft), "NFT");
    }

    function testRevealRarities() public {
        uint256[] memory rarities = new uint256[](MAX_SUPPLY);

        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            rarities[i] = 1;
        }

        nft.revealRarities(rarities);

        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            assertEq(nft.rarityOf(i), 1);
        }

        assertEq(nft.raritiesSum(), MAX_SUPPLY);
    }

    function testRevealRaritiesLengthMismatch() public {
        uint256[] memory rarities = new uint256[](MAX_SUPPLY - 1);
        vm.expectRevert(RaritiesLengthMismatch.selector);
        nft.revealRarities(rarities);

        rarities = new uint256[](MAX_SUPPLY + 1);
        vm.expectRevert(RaritiesLengthMismatch.selector);
        nft.revealRarities(rarities);

        rarities = new uint256[](0);
        vm.expectRevert(RaritiesLengthMismatch.selector);
        nft.revealRarities(rarities);
    }

    function testRevealMetadataUnauthorized() public {
        uint256[] memory rarities = new uint256[](MAX_SUPPLY);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.revealRarities(rarities);
    }

    function testRarityOfNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(NonExistentTokenId.selector, MAX_SUPPLY + 1));
        nft.rarityOf(MAX_SUPPLY + 1);
    }

    function testRoyalty() public {
        address expectedReceiver = address(nft.PAYMENT_SPLITTER());

        (address receiver, uint256 amount) = nft.royaltyInfo(0, 100);
        assertEq(receiver, expectedReceiver);
        assertEq(amount, (100 * ROYALTY_BP) / 1e4);

        (receiver, amount) = nft.royaltyInfo(1, 0);
        assertEq(receiver, expectedReceiver);
        assertEq(amount, 0);

        (receiver, amount) = nft.royaltyInfo(MAX_SUPPLY - 1, 123456);
        assertEq(receiver, expectedReceiver);
        assertEq(amount, (123456 * ROYALTY_BP) / 1e4);
    }
}
