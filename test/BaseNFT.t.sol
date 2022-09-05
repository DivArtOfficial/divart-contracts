// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.14;

import "../src/BaseNFT.sol";
import "forge-std/Test.sol";

contract BaseNFTTest is Test {
    uint256 constant MAX_SUPPLY = 10;
    uint256 constant RESERVED_SUPPLY = 1;
    uint256 constant MINTABLE_SUPPLY = MAX_SUPPLY - RESERVED_SUPPLY;
    uint256 constant EXCLUSIVE_WHITELIST_MINT_PRICE = 0.08 ether;
    uint256 constant WHITELIST_MINT_PRICE = 0.09 ether;
    uint256 constant PUBLIC_MINT_PRICE = 0.1 ether;
    uint256 constant DIVIDENDS_SHARE_BP = 1000;

    address projectTreasury = address(1);
    address dividendsTreasury = address(2);
    address alice = address(3);

    BaseNFT nft;

    function setUp() public {
        nft = new BaseNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            RESERVED_SUPPLY,
            EXCLUSIVE_WHITELIST_MINT_PRICE,
            WHITELIST_MINT_PRICE,
            PUBLIC_MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP,
            block.timestamp + 1
        );

        vm.label(address(this), "Owner");
        vm.label(projectTreasury, "ProjectTreasury");
        vm.label(dividendsTreasury, "DividendsTreasury");
        vm.label(alice, "Alice");
        vm.label(address(nft), "NFT");
    }

    function stopMinting() public {
        vm.warp(nft.mintStartTimestamp() - 1);
    }

    function startExclusiveWhitelistMinting() public {
        vm.warp(nft.mintStartTimestamp());
    }

    function startWhitelistMinting() public {
        vm.warp(nft.mintStartTimestamp() + 1 days);
    }

    function startPublicMinting() public {
        vm.warp(nft.mintStartTimestamp() + 2 days);
    }

    function testDeployment() public {
        BaseNFT _nft = new BaseNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            RESERVED_SUPPLY,
            EXCLUSIVE_WHITELIST_MINT_PRICE,
            WHITELIST_MINT_PRICE,
            PUBLIC_MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP,
            block.timestamp
        );
        assertEq(_nft.balanceOf(projectTreasury), RESERVED_SUPPLY);

        vm.expectRevert(ZeroMaxSupply.selector);
        new BaseNFT(
            "name",
            "symbol",
            0,
            RESERVED_SUPPLY,
            EXCLUSIVE_WHITELIST_MINT_PRICE,
            WHITELIST_MINT_PRICE,
            PUBLIC_MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP,
            block.timestamp
        );

        vm.expectRevert(ReservedExceedsMaxSupply.selector);
        new BaseNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            MAX_SUPPLY + 1,
            EXCLUSIVE_WHITELIST_MINT_PRICE,
            WHITELIST_MINT_PRICE,
            PUBLIC_MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP,
            block.timestamp
        );

        vm.expectRevert(DividentsShareBPTooHigh.selector);
        new BaseNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            RESERVED_SUPPLY,
            EXCLUSIVE_WHITELIST_MINT_PRICE,
            WHITELIST_MINT_PRICE,
            PUBLIC_MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            10001,
            block.timestamp
        );
    }

    function testWhitelistMintToWithExactPayment() public {
        vm.deal(alice, WHITELIST_MINT_PRICE);
        nft.addWhitelistSpots(alice, 1);
        startWhitelistMinting();
        vm.prank(alice);
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE }(alice, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.whitelistSpots(alice), 0);
        assertEq(projectTreasury.balance, nft.projectSharePerWhitelistMint());
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerWhitelistMint());

        vm.deal(address(this), WHITELIST_MINT_PRICE);
        stopMinting();
        nft.addWhitelistSpots(address(this), 1);
        startWhitelistMinting();
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE }(alice, 1);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.whitelistSpots(address(this)), 0);
        assertEq(projectTreasury.balance, nft.projectSharePerWhitelistMint() * 2);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerWhitelistMint() * 2);
    }

    function testWhitelistMintToWithExcessPayment() public {
        vm.deal(alice, WHITELIST_MINT_PRICE * 2);
        nft.addWhitelistSpots(alice, 2);
        startWhitelistMinting();
        vm.prank(alice);
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE * 2 }(alice, 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.whitelistSpots(alice), 1);
        assertEq(projectTreasury.balance, nft.projectSharePerWhitelistMint());
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerWhitelistMint());
        assertEq(alice.balance, WHITELIST_MINT_PRICE);

        vm.deal(address(this), WHITELIST_MINT_PRICE * 2);
        stopMinting();
        nft.addWhitelistSpots(address(this), 2);
        startWhitelistMinting();
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE * 2 }(alice, 1);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.whitelistSpots(address(this)), 1);
        assertEq(projectTreasury.balance, nft.projectSharePerWhitelistMint() * 2);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerWhitelistMint() * 2);
        assertEq(alice.balance, WHITELIST_MINT_PRICE);
    }

    function testWhitelistMintToWithInsufficientPayment() public {
        nft.addWhitelistSpots(alice, 1);
        startWhitelistMinting();
        vm.prank(alice);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.whitelistMint(alice, 1);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.whitelistSpots(alice), 1);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(alice.balance, 0);

        vm.deal(alice, WHITELIST_MINT_PRICE / 2);
        vm.prank(alice);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE / 2 }(alice, 1);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.whitelistSpots(alice), 1);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(alice.balance, WHITELIST_MINT_PRICE / 2);

        vm.deal(address(this), WHITELIST_MINT_PRICE / 2);
        stopMinting();
        nft.addWhitelistSpots(address(this), 1);
        startWhitelistMinting();
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE / 2 }(alice, 1);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.whitelistSpots(address(this)), 1);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(address(this).balance, WHITELIST_MINT_PRICE / 2);
    }

    function testPublicMintToWithMaxSupplyReached() public {
        vm.deal(alice, PUBLIC_MINT_PRICE * (MINTABLE_SUPPLY + 1));
        startPublicMinting();
        vm.startPrank(alice);
        for (uint256 i = 0; i < MINTABLE_SUPPLY; i++) {
            nft.publicMint{ value: PUBLIC_MINT_PRICE }(alice, 1);
        }
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        vm.expectRevert(MaxSupplyReached.selector);
        nft.publicMint{ value: PUBLIC_MINT_PRICE }(alice, 1);
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        vm.stopPrank();

        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        assertEq(projectTreasury.balance, nft.projectSharePerPublicMint() * MINTABLE_SUPPLY);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerPublicMint() * MINTABLE_SUPPLY);

        vm.deal(address(this), PUBLIC_MINT_PRICE);
        vm.expectRevert(MaxSupplyReached.selector);
        nft.publicMint{ value: PUBLIC_MINT_PRICE }(alice, 1);
    }

    function testExclusiveWhitelistMintBatchToWithExactPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY / 2);

        vm.deal(alice, EXCLUSIVE_WHITELIST_MINT_PRICE * amount);
        nft.addExclusiveWhitelistSpots(alice, amount);
        startExclusiveWhitelistMinting();
        vm.prank(alice);
        nft.exclusiveWhitelistMint{ value: EXCLUSIVE_WHITELIST_MINT_PRICE * amount }(alice, amount);
        assertEq(nft.balanceOf(alice), amount * 2);
        assertEq(nft.exclusiveWhitelistSpots(alice), 0);
        assertEq(projectTreasury.balance, nft.projectSharePerExclusiveWhitelistMint() * amount);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerExclusiveWhitelistMint() * amount);

        amount = (MINTABLE_SUPPLY - amount * 2) / 2;
        vm.assume(amount > 0);
        vm.deal(address(this), EXCLUSIVE_WHITELIST_MINT_PRICE * amount);
        stopMinting();
        nft.addExclusiveWhitelistSpots(address(this), amount);
        startExclusiveWhitelistMinting();
        nft.exclusiveWhitelistMint{ value: EXCLUSIVE_WHITELIST_MINT_PRICE * amount }(alice, amount);
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY - (MINTABLE_SUPPLY % 2));
        assertEq(nft.exclusiveWhitelistSpots(address(this)), 0);
        assertEq(projectTreasury.balance, nft.projectSharePerExclusiveWhitelistMint() * (MINTABLE_SUPPLY / 2));
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerExclusiveWhitelistMint() * (MINTABLE_SUPPLY / 2));
    }

    function testExclusiveWhitelistMintBatchToWithInsufficientPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY / 2);

        uint256 topUpAmount = (EXCLUSIVE_WHITELIST_MINT_PRICE * amount) / 2;
        vm.deal(alice, topUpAmount);
        nft.addExclusiveWhitelistSpots(alice, amount);
        startExclusiveWhitelistMinting();
        vm.prank(alice);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.exclusiveWhitelistMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.exclusiveWhitelistSpots(alice), amount);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(alice.balance, topUpAmount);

        vm.deal(address(this), topUpAmount);
        stopMinting();
        nft.clearExclusiveWhitelistSpots(alice);
        nft.addExclusiveWhitelistSpots(address(this), amount);
        startExclusiveWhitelistMinting();
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.exclusiveWhitelistMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.exclusiveWhitelistSpots(address(this)), amount);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(address(this).balance, topUpAmount);
    }

    function testExclusiveWhitelistMintBatchToWithExcessPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY / 2);

        nft.addExclusiveWhitelistSpots(alice, amount);
        startExclusiveWhitelistMinting();

        uint256 topUpAmount = (EXCLUSIVE_WHITELIST_MINT_PRICE * amount) * 2;
        vm.deal(alice, topUpAmount);
        vm.prank(alice);
        nft.exclusiveWhitelistMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), amount * 2);
        assertEq(nft.exclusiveWhitelistSpots(alice), 0);
        assertEq(projectTreasury.balance, nft.projectSharePerExclusiveWhitelistMint() * amount);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerExclusiveWhitelistMint() * amount);
        assertEq(alice.balance, topUpAmount / 2);

        amount = (MINTABLE_SUPPLY - amount * 2) / 2;
        vm.assume(amount > 0);
        topUpAmount = EXCLUSIVE_WHITELIST_MINT_PRICE * amount * 2;
        vm.deal(address(this), topUpAmount);
        stopMinting();
        nft.addExclusiveWhitelistSpots(address(this), amount);
        startExclusiveWhitelistMinting();
        nft.exclusiveWhitelistMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY - (MINTABLE_SUPPLY % 2));
        assertEq(nft.exclusiveWhitelistSpots(address(this)), 0);
        assertEq(projectTreasury.balance, nft.projectSharePerExclusiveWhitelistMint() * (MINTABLE_SUPPLY / 2));
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerExclusiveWhitelistMint() * (MINTABLE_SUPPLY / 2));
        assertEq(address(this).balance, topUpAmount / 2);
    }

    function testExclusiveWhitelistMintBatchToInvalidAmount() public {
        nft.addExclusiveWhitelistSpots(address(this), 1);
        nft.addExclusiveWhitelistSpots(address(alice), 1);
        startExclusiveWhitelistMinting();

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        nft.exclusiveWhitelistMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.prank(alice);
        nft.exclusiveWhitelistMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.deal(address(this), EXCLUSIVE_WHITELIST_MINT_PRICE);
        nft.exclusiveWhitelistMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.deal(alice, EXCLUSIVE_WHITELIST_MINT_PRICE);
        vm.prank(alice);
        nft.exclusiveWhitelistMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, MAX_SUPPLY + 1));
        nft.exclusiveWhitelistMint(alice, MAX_SUPPLY + 1);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, MAX_SUPPLY + 1));
        vm.prank(alice);
        nft.exclusiveWhitelistMint(alice, MAX_SUPPLY + 1);
        assertEq(nft.balanceOf(alice), 0);

        assertEq(nft.exclusiveWhitelistSpots(address(this)), 1);
        assertEq(nft.exclusiveWhitelistSpots(address(alice)), 1);
    }

    function testPublicMintBatchToWithExactPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY / 2);

        vm.deal(alice, PUBLIC_MINT_PRICE * amount);
        startPublicMinting();
        vm.prank(alice);
        nft.publicMint{ value: PUBLIC_MINT_PRICE * amount }(alice, amount);
        assertEq(nft.balanceOf(alice), amount);
        assertEq(projectTreasury.balance, nft.projectSharePerPublicMint() * amount);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerPublicMint() * amount);

        amount = MINTABLE_SUPPLY - amount;
        vm.assume(amount > 0);
        vm.deal(address(this), PUBLIC_MINT_PRICE * amount);
        stopMinting();
        startPublicMinting();
        nft.publicMint{ value: PUBLIC_MINT_PRICE * amount }(alice, amount);
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        assertEq(projectTreasury.balance, nft.projectSharePerPublicMint() * MINTABLE_SUPPLY);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerPublicMint() * MINTABLE_SUPPLY);
    }

    function testPublicMintBatchToWithInsufficientPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY / 2);

        uint256 topUpAmount = (PUBLIC_MINT_PRICE * amount) / 2;
        vm.deal(alice, topUpAmount);
        startPublicMinting();
        vm.prank(alice);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.publicMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(alice.balance, topUpAmount);

        vm.deal(address(this), topUpAmount);
        stopMinting();
        startPublicMinting();
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.publicMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(address(this).balance, topUpAmount);
    }

    function testPublicMintBatchToWithExcessPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY);

        startPublicMinting();

        uint256 topUpAmount = (PUBLIC_MINT_PRICE * amount) * 2;
        vm.deal(alice, topUpAmount);
        vm.prank(alice);
        nft.publicMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), amount);
        assertEq(projectTreasury.balance, nft.projectSharePerPublicMint() * amount);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerPublicMint() * amount);
        assertEq(alice.balance, topUpAmount / 2);

        amount = MINTABLE_SUPPLY - amount;
        vm.assume(amount > 0);
        topUpAmount = PUBLIC_MINT_PRICE * amount * 2;
        vm.deal(address(this), topUpAmount);
        stopMinting();
        startPublicMinting();
        nft.publicMint{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        assertEq(projectTreasury.balance, nft.projectSharePerPublicMint() * MINTABLE_SUPPLY);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerPublicMint() * MINTABLE_SUPPLY);
        assertEq(address(this).balance, topUpAmount / 2);
    }

    function testPublicMintBatchToInvalidAmount() public {
        startPublicMinting();

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        nft.publicMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.prank(alice);
        nft.publicMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.deal(address(this), PUBLIC_MINT_PRICE);
        nft.publicMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.deal(alice, PUBLIC_MINT_PRICE);
        vm.prank(alice);
        nft.publicMint(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, MAX_SUPPLY + 1));
        nft.publicMint(alice, MAX_SUPPLY + 1);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, MAX_SUPPLY + 1));
        vm.prank(alice);
        nft.publicMint(alice, MAX_SUPPLY + 1);
        assertEq(nft.balanceOf(alice), 0);
    }

    function testRevealMetadata() public {
        string memory uri = "https://example.com/";
        string memory tokenUri = "https://example.com/0";
        nft.revealMetadata(uri);
        assertEq(keccak256(abi.encodePacked(nft.tokenURI(0))), keccak256(abi.encodePacked(tokenUri)));
    }

    function testRevealMetadataEmptyURI() public {
        vm.expectRevert(EmptyURI.selector);
        nft.revealMetadata("");
    }

    function testRevealMetadataUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.revealMetadata("https://example.com/");
    }

    function testMintingPaused() public {
        nft.pause();
        vm.deal(address(this), WHITELIST_MINT_PRICE * 3);
        nft.addWhitelistSpots(address(this), 3);
        startWhitelistMinting();
        vm.expectRevert("Pausable: paused");
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE }(alice, 1);
        assertEq(nft.balanceOf(alice), 0);
        vm.expectRevert("Pausable: paused");
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE * 3 }(alice, 3);
        assertEq(nft.balanceOf(alice), 0);

        nft.unpause();
        nft.whitelistMint{ value: WHITELIST_MINT_PRICE }(alice, 1);
        assertEq(nft.balanceOf(alice), 1);
    }

    function testPauseUnpause() public {
        nft.pause();
        nft.unpause();
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.pause();
        vm.expectRevert("Ownable: caller is not the owner");
        nft.unpause();
        vm.stopPrank();
    }

    function testAddExclusiveWhitelistSpots() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.addExclusiveWhitelistSpots(alice, 1);
        assertEq(nft.exclusiveWhitelistSpots(alice), 0);

        nft.addExclusiveWhitelistSpots(alice, 1);
        assertEq(nft.exclusiveWhitelistSpots(alice), 1);
    }

    function testRemoveExclusiveWhitelistSpots() public {
        nft.addExclusiveWhitelistSpots(alice, 2);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.removeExclusiveWhitelistSpots(alice, 1);
        assertEq(nft.exclusiveWhitelistSpots(alice), 2);

        vm.expectRevert(NotEnoughExclusiveWhitelistSpots.selector);
        nft.removeExclusiveWhitelistSpots(alice, 3);
        assertEq(nft.exclusiveWhitelistSpots(alice), 2);

        nft.removeExclusiveWhitelistSpots(alice, 1);
        assertEq(nft.exclusiveWhitelistSpots(alice), 1);
    }

    function testClearExclusiveWhitelistSpots() public {
        nft.addExclusiveWhitelistSpots(alice, 2);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.clearExclusiveWhitelistSpots(alice);
        assertEq(nft.exclusiveWhitelistSpots(alice), 2);

        nft.clearExclusiveWhitelistSpots(alice);
        assertEq(nft.exclusiveWhitelistSpots(alice), 0);
    }

    function testMultipleAddExclusiveWhitelistSpots() public {
        address[] memory addresses = new address[](3);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(ArrayLengthMismatch.selector);
        nft.addExclusiveWhitelistSpots(addresses, amounts);

        amounts = new uint256[](3);

        addresses[0] = alice;
        addresses[1] = alice;
        addresses[2] = address(1337);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 2;
        nft.addExclusiveWhitelistSpots(addresses, amounts);
        assertEq(nft.exclusiveWhitelistSpots(alice), 2);
        assertEq(nft.exclusiveWhitelistSpots(address(1337)), 2);
    }

    function testAddWhitelistSpots() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.addWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 0);

        nft.addWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 1);
    }

    function testRemoveWhitelistSpots() public {
        nft.addWhitelistSpots(alice, 2);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.removeWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 2);

        vm.expectRevert(NotEnoughWhitelistSpots.selector);
        nft.removeWhitelistSpots(alice, 3);
        assertEq(nft.whitelistSpots(alice), 2);

        nft.removeWhitelistSpots(alice, 1);
        assertEq(nft.whitelistSpots(alice), 1);
    }

    function testClearWhitelistSpots() public {
        nft.addWhitelistSpots(alice, 2);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.clearWhitelistSpots(alice);
        assertEq(nft.whitelistSpots(alice), 2);

        nft.clearWhitelistSpots(alice);
        assertEq(nft.whitelistSpots(alice), 0);
    }

    function testMultipleAddWhitelistSpots() public {
        address[] memory addresses = new address[](3);
        uint256[] memory amounts = new uint256[](2);

        vm.expectRevert(ArrayLengthMismatch.selector);
        nft.addWhitelistSpots(addresses, amounts);

        amounts = new uint256[](3);

        addresses[0] = alice;
        addresses[1] = alice;
        addresses[2] = address(1337);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 2;
        nft.addWhitelistSpots(addresses, amounts);
        assertEq(nft.whitelistSpots(alice), 2);
        assertEq(nft.whitelistSpots(address(1337)), 2);
    }

    function testWhitelistSupplyConsistency() public {
        uint256 exclusiveWhitelistSpots = MINTABLE_SUPPLY / 4;
        uint256 whitelistSpots = MINTABLE_SUPPLY / 4;
        uint256 publicSpots = MINTABLE_SUPPLY - exclusiveWhitelistSpots * 2 - whitelistSpots;

        nft.addExclusiveWhitelistSpots(address(this), exclusiveWhitelistSpots);
        nft.addWhitelistSpots(address(this), whitelistSpots);
        assertEq(nft.exclusiveWhitelistSupply(), exclusiveWhitelistSpots);
        assertEq(nft.whitelistSupply(), whitelistSpots);

        vm.deal(address(this), EXCLUSIVE_WHITELIST_MINT_PRICE * exclusiveWhitelistSpots);
        startExclusiveWhitelistMinting();
        nft.exclusiveWhitelistMint{ value: address(this).balance }(alice, exclusiveWhitelistSpots);
        assertEq(nft.exclusiveWhitelistSupply(), 0);
        assertEq(nft.whitelistSupply(), whitelistSpots);
        assertEq(nft.totalSupply(), RESERVED_SUPPLY + exclusiveWhitelistSpots * 2);

        vm.deal(address(this), WHITELIST_MINT_PRICE * whitelistSpots);
        startWhitelistMinting();
        nft.whitelistMint{ value: address(this).balance }(alice, whitelistSpots);
        assertEq(nft.exclusiveWhitelistSupply(), 0);
        assertEq(nft.whitelistSupply(), 0);
        assertEq(nft.totalSupply(), RESERVED_SUPPLY + exclusiveWhitelistSpots * 2 + whitelistSpots);

        vm.deal(address(this), PUBLIC_MINT_PRICE * publicSpots);
        startPublicMinting();
        nft.publicMint{ value: address(this).balance }(alice, publicSpots);
        assertEq(nft.exclusiveWhitelistSupply(), 0);
        assertEq(nft.whitelistSupply(), 0);
        assertEq(nft.totalSupply(), RESERVED_SUPPLY + MINTABLE_SUPPLY);

        stopMinting();
        vm.expectRevert(MaxSupplyReached.selector);
        nft.addWhitelistSpots(address(this), 1);
        vm.expectRevert(MaxSupplyReached.selector);
        nft.addExclusiveWhitelistSpots(address(this), 1);
    }

    function testMintingNotLive() public {
        vm.expectRevert(ExclusiveWhitelistMintingNotLive.selector);
        nft.exclusiveWhitelistMint(alice, 1);

        vm.expectRevert(WhitelistMintingNotLive.selector);
        nft.whitelistMint(alice, 1);

        vm.expectRevert(PublicMintingNotLive.selector);
        nft.publicMint(alice, 1);
    }

    function testClaimUnmintedExclusiveWhitelistSpots() public {
        uint256 exclusiveWhitelistSpots = MINTABLE_SUPPLY / 2;
        nft.addExclusiveWhitelistSpots(address(this), exclusiveWhitelistSpots);
        vm.deal(address(this), (EXCLUSIVE_WHITELIST_MINT_PRICE * exclusiveWhitelistSpots) / 2);

        vm.expectRevert(ClaimBeforeMintingStarted.selector);
        nft.claimUnmintedExclusiveWhitelistSpots();

        startExclusiveWhitelistMinting();
        vm.expectRevert(ExclusiveWhitelistMintingLive.selector);
        nft.claimUnmintedExclusiveWhitelistSpots();

        nft.exclusiveWhitelistMint{ value: address(this).balance }(alice, exclusiveWhitelistSpots / 2);
        assertEq(nft.exclusiveWhitelistSupply(), exclusiveWhitelistSpots - exclusiveWhitelistSpots / 2);

        startPublicMinting();
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.claimUnmintedExclusiveWhitelistSpots();

        nft.claimUnmintedExclusiveWhitelistSpots();
        assertEq(nft.exclusiveWhitelistSupply(), 0);
        assertEq(nft.totalSupply(), RESERVED_SUPPLY + exclusiveWhitelistSpots * 2);
        assertEq(nft.balanceOf(alice), (exclusiveWhitelistSpots / 2) * 2);
        assertEq(nft.balanceOf(address(this)), 0);
        assertEq(
            nft.balanceOf(projectTreasury),
            RESERVED_SUPPLY + (exclusiveWhitelistSpots - exclusiveWhitelistSpots / 2) * 2
        );
    }

    function testMintStartTimestamp() public {
        assertEq(nft.mintStartTimestamp(), block.timestamp + 1);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        nft.setMintStartTimestamp(block.timestamp + 2);

        vm.expectRevert(PastTimestamp.selector);
        nft.setMintStartTimestamp(block.timestamp);

        vm.expectRevert(PastTimestamp.selector);
        nft.setMintStartTimestamp(block.timestamp - 1);

        startExclusiveWhitelistMinting();
        vm.expectRevert(MintingAlreadyStarted.selector);
        nft.setMintStartTimestamp(block.timestamp + 7 days);

        startWhitelistMinting();
        vm.expectRevert(MintingAlreadyStarted.selector);
        nft.setMintStartTimestamp(block.timestamp + 7 days);

        startPublicMinting();
        vm.expectRevert(MintingAlreadyStarted.selector);
        nft.setMintStartTimestamp(block.timestamp + 7 days);
    }

    receive() external payable {}
}
