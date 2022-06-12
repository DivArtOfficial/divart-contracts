// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.14;

import "../src/BaseNFT.sol";
import "@std/Test.sol";

contract BaseNFTTest is Test {
    uint256 MAX_SUPPLY = 10;
    uint256 RESERVED_SUPPLY = 1;
    uint256 MINTABLE_SUPPLY = MAX_SUPPLY - RESERVED_SUPPLY;
    uint256 MINT_PRICE = 0.08 ether;
    uint256 DIVIDENDS_SHARE_BP = 1000;

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
            MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP
        );

        vm.label(address(this), "Owner");
        vm.label(projectTreasury, "ProjectTreasury");
        vm.label(dividendsTreasury, "DividendsTreasury");
        vm.label(alice, "Alice");
        vm.label(address(nft), "NFT");
    }

    function testDeployment() public {
        BaseNFT _nft = new BaseNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            RESERVED_SUPPLY,
            MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP
        );
        assertEq(_nft.balanceOf(projectTreasury), RESERVED_SUPPLY);

        vm.expectRevert(ZeroMaxSupply.selector);
        new BaseNFT(
            "name",
            "symbol",
            0,
            RESERVED_SUPPLY,
            MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP
        );

        vm.expectRevert(ReservedExceedsMaxSupply.selector);
        new BaseNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            MAX_SUPPLY + 1,
            MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            DIVIDENDS_SHARE_BP
        );

        vm.expectRevert(DividentsShareBPTooHigh.selector);
        new BaseNFT(
            "name",
            "symbol",
            MAX_SUPPLY,
            RESERVED_SUPPLY,
            MINT_PRICE,
            dividendsTreasury,
            projectTreasury,
            10001
        );
    }

    function testMintToWithExactPayment() public {
        vm.deal(alice, MINT_PRICE);
        vm.prank(alice);
        nft.mintTo{ value: MINT_PRICE }(alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(projectTreasury.balance, nft.projectSharePerMint());
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint());

        vm.deal(address(this), MINT_PRICE);
        vm.prank(address(this));
        nft.mintTo{ value: MINT_PRICE }(alice);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(projectTreasury.balance, nft.projectSharePerMint() * 2);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint() * 2);
    }

    function testMintToWithExcessPayment() public {
        vm.deal(alice, MINT_PRICE * 2);
        vm.prank(alice);
        nft.mintTo{ value: MINT_PRICE * 2 }(alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(projectTreasury.balance, nft.projectSharePerMint());
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint());
        assertEq(alice.balance, MINT_PRICE);

        vm.deal(address(this), MINT_PRICE * 2);
        vm.prank(address(this));
        nft.mintTo{ value: MINT_PRICE * 2 }(alice);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(projectTreasury.balance, nft.projectSharePerMint() * 2);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint() * 2);
        assertEq(alice.balance, MINT_PRICE);
    }

    function testMintToWithInsufficientPayment() public {
        vm.prank(alice);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.mintTo(alice);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(alice.balance, 0);

        vm.deal(alice, MINT_PRICE / 2);
        vm.prank(alice);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.mintTo{ value: MINT_PRICE / 2 }(alice);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(alice.balance, MINT_PRICE / 2);

        vm.deal(address(this), MINT_PRICE / 2);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.mintTo{ value: MINT_PRICE / 2 }(alice);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(address(this).balance, MINT_PRICE / 2);
    }

    function testMintToWithMaxSupplyReached() public {
        vm.deal(alice, MINT_PRICE * (MINTABLE_SUPPLY + 1));
        vm.startPrank(alice);
        for (uint256 i = 0; i < MINTABLE_SUPPLY; i++) {
            nft.mintTo{ value: MINT_PRICE }(alice);
        }
        vm.expectRevert(MaxSupplyReached.selector);
        nft.mintTo{ value: MINT_PRICE }(alice);
        vm.stopPrank();

        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        assertEq(projectTreasury.balance, nft.projectSharePerMint() * MINTABLE_SUPPLY);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint() * MINTABLE_SUPPLY);

        vm.deal(address(this), MINT_PRICE);
        vm.expectRevert(MaxSupplyReached.selector);
        nft.mintTo{ value: MINT_PRICE }(alice);
    }

    function testMintBatchToWithExactPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY);

        vm.deal(alice, MINT_PRICE * amount);
        vm.prank(alice);
        nft.mintBatchTo{ value: MINT_PRICE * amount }(alice, amount);
        assertEq(nft.balanceOf(alice), amount);
        assertEq(projectTreasury.balance, nft.projectSharePerMint() * amount);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint() * amount);

        amount = MINTABLE_SUPPLY - amount;
        vm.assume(amount > 0);
        vm.deal(address(this), MINT_PRICE * amount);
        nft.mintBatchTo{ value: MINT_PRICE * amount }(alice, amount);
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        assertEq(projectTreasury.balance, nft.projectSharePerMint() * MINTABLE_SUPPLY);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint() * MINTABLE_SUPPLY);
    }

    function testMintBatchToWithInsufficentPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY);

        uint256 topUpAmount = (MINT_PRICE * amount) / 2;
        vm.deal(alice, topUpAmount);
        vm.prank(alice);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.mintBatchTo{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(alice.balance, topUpAmount);

        vm.deal(address(this), topUpAmount);
        vm.expectRevert(MintPriceNotPaid.selector);
        nft.mintBatchTo{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(projectTreasury.balance, 0);
        assertEq(dividendsTreasury.balance, 0);
        assertEq(address(this).balance, topUpAmount);
    }

    function testMintBatchToWithExcessPayment(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINTABLE_SUPPLY);

        uint256 topUpAmount = (MINT_PRICE * amount) * 2;
        vm.deal(alice, topUpAmount);
        vm.prank(alice);
        nft.mintBatchTo{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), amount);
        assertEq(projectTreasury.balance, nft.projectSharePerMint() * amount);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint() * amount);
        assertEq(alice.balance, topUpAmount / 2);

        amount = MINTABLE_SUPPLY - amount;
        vm.assume(amount > 0);
        topUpAmount = MINT_PRICE * amount * 2;
        vm.deal(address(this), topUpAmount);
        nft.mintBatchTo{ value: topUpAmount }(alice, amount);
        assertEq(nft.balanceOf(alice), MINTABLE_SUPPLY);
        assertEq(projectTreasury.balance, nft.projectSharePerMint() * MINTABLE_SUPPLY);
        assertEq(dividendsTreasury.balance, nft.dividendsSharePerMint() * MINTABLE_SUPPLY);
        assertEq(address(this).balance, topUpAmount / 2);
    }

    function testMintBatchToInvalidAmount() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        nft.mintBatchTo(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.prank(alice);
        nft.mintBatchTo(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.deal(address(this), MINT_PRICE);
        nft.mintBatchTo(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, 0));
        vm.deal(alice, MINT_PRICE);
        vm.prank(alice);
        nft.mintBatchTo(alice, 0);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, MAX_SUPPLY + 1));
        nft.mintBatchTo(alice, MAX_SUPPLY + 1);
        assertEq(nft.balanceOf(alice), 0);

        vm.expectRevert(abi.encodeWithSelector(InvalidAmount.selector, MAX_SUPPLY + 1));
        vm.prank(alice);
        nft.mintBatchTo(alice, MAX_SUPPLY + 1);
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

    receive() external payable {}
}
