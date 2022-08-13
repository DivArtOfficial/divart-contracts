// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import "../src/DividendsTreasury.sol";
import "../src/BuildingBlocksNFT.sol";
import "forge-std/Test.sol";
import "ERC721A/IERC721A.sol";

contract DividendsTreasuryTest is Test {
    uint256 constant MAX_SUPPLY = 10;
    uint256 constant RESERVED_SUPPLY = 0;
    uint256 constant MINTABLE_SUPPLY = MAX_SUPPLY - RESERVED_SUPPLY;
    uint256 constant MINT_PRICE = 0.08 ether;
    uint256 constant DIVIDENDS_SHARE_BP = 1e3;
    uint96 constant ROYALTY_BP = 2e3;
    uint256 constant DIVIDENDS_ROYALTY_SHARES = 8;
    uint256 constant PROJECT_ROYALTY_SHARES = 2;

    address projectTreasury = address(1);
    address alice = address(2);
    address bob = address(3);

    BuildingBlocksNFT buildingBlocksNFT;
    DividendsTreasury dividendsTreasury;

    function setUp() public {
        vm.label(address(this), "Owner");
        vm.label(projectTreasury, "ProjectTreasury");
        vm.label(address(buildingBlocksNFT), "BuildingBlocksNFT");
        vm.label(address(dividendsTreasury), "DividendsTreasury");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");

        dividendsTreasury = new DividendsTreasury(projectTreasury);

        buildingBlocksNFT = new BuildingBlocksNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            RESERVED_SUPPLY,
            MINT_PRICE,
            address(dividendsTreasury),
            projectTreasury,
            DIVIDENDS_SHARE_BP,
            ROYALTY_BP,
            DIVIDENDS_ROYALTY_SHARES,
            PROJECT_ROYALTY_SHARES
        );

        dividendsTreasury.initialize((address(buildingBlocksNFT)), buildingBlocksNFT);

        vm.deal(address(this), MINT_PRICE * MINTABLE_SUPPLY);
        buildingBlocksNFT.addWhitelistSpots(address(this), MINTABLE_SUPPLY);
        uint256 aliceAmount = MINTABLE_SUPPLY / 2;
        buildingBlocksNFT.mint{ value: MINT_PRICE * aliceAmount }(alice, aliceAmount);
        uint256 bobAmount = (MINTABLE_SUPPLY + 1) / 2;
        buildingBlocksNFT.mint{ value: MINT_PRICE * bobAmount }(bob, bobAmount);

        uint256[] memory rarities = new uint256[](MAX_SUPPLY);
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            rarities[i] = 1;
        }
        buildingBlocksNFT.revealRarities(rarities);
    }

    function testReceiveFunds() public {
        uint256 initialBalance = MAX_SUPPLY * buildingBlocksNFT.dividendsSharePerMint();
        assertEq(address(dividendsTreasury).balance, initialBalance);
        assertEq(dividendsTreasury.treasuryBalance(), initialBalance);

        vm.deal(address(this), 1 ether);
        (bool success, ) = address(dividendsTreasury).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(dividendsTreasury).balance, initialBalance + 1 ether);
        assertEq(dividendsTreasury.treasuryBalance(), initialBalance + 1 ether);

        (success, ) = address(dividendsTreasury).call{ value: 0 ether }("");
        assertTrue(success);
        assertEq(address(dividendsTreasury).balance, initialBalance + 1 ether);
        assertEq(dividendsTreasury.treasuryBalance(), initialBalance + 1 ether);
    }

    function testIssueDividends() public {
        uint256 initialTreasuryBalance = dividendsTreasury.treasuryBalance();
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        dividendsTreasury.issueDividends(initialTreasuryBalance, 42);
        assertEq(dividendsTreasury.treasuryBalance(), initialTreasuryBalance);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);

        vm.expectRevert(DividendsAmountExceedsBalance.selector);
        dividendsTreasury.issueDividends(initialTreasuryBalance + 1 ether, 42);
        assertEq(dividendsTreasury.treasuryBalance(), initialTreasuryBalance);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);

        vm.expectRevert(ZeroDividendsAmount.selector);
        dividendsTreasury.issueDividends(0, 42);
        assertEq(dividendsTreasury.treasuryBalance(), initialTreasuryBalance);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);

        vm.expectRevert(NullDuration.selector);
        dividendsTreasury.issueDividends(initialTreasuryBalance, 0);
        assertEq(dividendsTreasury.treasuryBalance(), initialTreasuryBalance);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);

        dividendsTreasury.issueDividends(initialTreasuryBalance / 2, 42);
        assertEq(dividendsTreasury.treasuryBalance(), initialTreasuryBalance / 2);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);

        vm.expectRevert(LastRoundNotClosed.selector);
        dividendsTreasury.issueDividends((initialTreasuryBalance + 1) / 2, 42);
        assertEq(dividendsTreasury.treasuryBalance(), (initialTreasuryBalance + 1) / 2);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);

        vm.warp(block.timestamp + 42);
        dividendsTreasury.issueDividends((initialTreasuryBalance + 1) / 2, 42);
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);
    }

    function testCalculateDividendsForAccount() public {
        uint256 treasuryBalance = dividendsTreasury.treasuryBalance();
        dividendsTreasury.issueDividends(treasuryBalance, 1337);

        uint256 aliceTokensCount = MINTABLE_SUPPLY / 2;
        assertEq(
            dividendsTreasury.calculateDividendsForAccount(alice, 0),
            (treasuryBalance * aliceTokensCount) / MAX_SUPPLY
        );

        uint256 bobTokensCount = (MINTABLE_SUPPLY + 1) / 2;
        assertEq(
            dividendsTreasury.calculateDividendsForAccount(bob, 0),
            (treasuryBalance * bobTokensCount) / MAX_SUPPLY
        );

        assertEq(dividendsTreasury.calculateDividendsForAccount(projectTreasury, 0), RESERVED_SUPPLY / MAX_SUPPLY);
    }

    function testCalculateDividendsForToken() public {
        uint256 treasuryBalance = dividendsTreasury.treasuryBalance();
        dividendsTreasury.issueDividends(treasuryBalance, 1337);

        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            assertEq(dividendsTreasury.calculateDividendsForToken(i, 0), treasuryBalance / MAX_SUPPLY);
        }
    }

    function testClaimDividendsForToken() public {
        uint256 initialTreasuryBalance = dividendsTreasury.treasuryBalance();
        dividendsTreasury.issueDividends(initialTreasuryBalance, 1337);

        address ownerOf1 = buildingBlocksNFT.ownerOf(1);
        vm.prank(ownerOf1);
        dividendsTreasury.claimDividendsForToken(1);
        assertEq(ownerOf1.balance, initialTreasuryBalance / MAX_SUPPLY);
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance - initialTreasuryBalance / MAX_SUPPLY);

        vm.expectRevert(abi.encodeWithSelector(DividendsAlreadyClaimedForToken.selector, 1));
        vm.prank(ownerOf1);
        dividendsTreasury.claimDividendsForToken(1);

        vm.expectRevert(TokenNotOwnedByAccount.selector);
        dividendsTreasury.claimDividendsForToken(2);

        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        dividendsTreasury.claimDividendsForToken(MAX_SUPPLY);

        vm.warp(block.timestamp + 1337);
        address ownerOf2 = buildingBlocksNFT.ownerOf(2);
        vm.expectRevert(LastRoundNotOpen.selector);
        vm.prank(ownerOf2);
        dividendsTreasury.claimDividendsForToken(2);
    }

    function testClaimAllDividends() public {
        // claim dividends for Alice
        uint256 initialTreasuryBalance = dividendsTreasury.treasuryBalance();
        dividendsTreasury.issueDividends(initialTreasuryBalance, 1337);

        uint256 aliceDividends = (MINTABLE_SUPPLY * initialTreasuryBalance) / 2 / MAX_SUPPLY;
        vm.prank(alice);
        dividendsTreasury.claimDividends();
        assertEq(alice.balance, aliceDividends);
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance - aliceDividends);

        vm.prank(alice);
        dividendsTreasury.claimDividends();
        assertEq(alice.balance, aliceDividends);
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance - aliceDividends);

        dividendsTreasury.claimDividends();
        assertEq(bob.balance, 0);
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance - aliceDividends);

        vm.warp(block.timestamp + 2337);
        vm.expectRevert(LastRoundNotOpen.selector);
        dividendsTreasury.claimDividends();
    }

    function testTerminateDividendsRound() public {
        uint256 initialTreasuryBalance = dividendsTreasury.treasuryBalance();
        dividendsTreasury.issueDividends(initialTreasuryBalance, 1337);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        dividendsTreasury.terminateDividendsRound();

        dividendsTreasury.terminateDividendsRound();
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);
        assertEq(dividendsTreasury.getDividendsRound(0).endTimestamp, block.timestamp);
    }

    function testWithdraw() public {
        uint256 initialTreasuryBalance = dividendsTreasury.treasuryBalance();
        uint256 initialProjectTreasuryBalance = projectTreasury.balance;

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        dividendsTreasury.withdraw(initialTreasuryBalance);

        vm.expectRevert(WithdrawalAmountExceedsBalance.selector);
        dividendsTreasury.withdraw(initialTreasuryBalance + 1);

        dividendsTreasury.withdraw(initialTreasuryBalance / 2);
        assertEq(dividendsTreasury.treasuryBalance(), (initialTreasuryBalance + 1) / 2);
        assertEq(address(dividendsTreasury).balance, (initialTreasuryBalance + 1) / 2);
        assertEq(projectTreasury.balance, initialTreasuryBalance / 2 + initialProjectTreasuryBalance);

        uint256 newTreasuryBalance = dividendsTreasury.treasuryBalance();
        dividendsTreasury.issueDividends(newTreasuryBalance / 2, 1337);

        dividendsTreasury.withdraw((newTreasuryBalance + 1) / 2);
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(dividendsTreasury).balance, newTreasuryBalance / 2);
        assertEq(
            projectTreasury.balance,
            initialTreasuryBalance / 2 + (newTreasuryBalance + 1) / 2 + initialProjectTreasuryBalance
        );
    }

    function testWithdrawUnclaimed() public {
        uint256 initialTreasuryBalance = dividendsTreasury.treasuryBalance();
        uint256 initialProjectTreasuryBalance = projectTreasury.balance;

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        dividendsTreasury.withdrawUnclaimed();

        dividendsTreasury.issueDividends(initialTreasuryBalance, 1337);
        vm.expectRevert(LastRoundNotClosed.selector);
        dividendsTreasury.withdrawUnclaimed();

        vm.warp(block.timestamp + 1337);
        dividendsTreasury.withdrawUnclaimed();
        assertEq(dividendsTreasury.treasuryBalance(), 0);
        assertEq(address(projectTreasury).balance, initialTreasuryBalance + initialProjectTreasuryBalance);
    }

    function testWaiveUnclaimed() public {
        uint256 initialTreasuryBalance = dividendsTreasury.treasuryBalance();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        dividendsTreasury.waiveUnclaimed();

        dividendsTreasury.issueDividends(initialTreasuryBalance, 1337);
        vm.expectRevert(LastRoundNotClosed.selector);
        dividendsTreasury.waiveUnclaimed();

        vm.warp(block.timestamp + 1337);
        dividendsTreasury.waiveUnclaimed();
        assertEq(dividendsTreasury.treasuryBalance(), initialTreasuryBalance);
        assertEq(address(dividendsTreasury).balance, initialTreasuryBalance);
    }

    receive() external payable {}
}
