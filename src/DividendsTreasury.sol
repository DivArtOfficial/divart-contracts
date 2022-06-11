// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { RarityOracle } from "./interfaces/RarityOracle.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

error LastRoundNotClosed();
error LastRoundAlreadyClosed();
error DividendsAmountExceedsBalance();
error DurationCannotBeZero();
error WithdrawalFailed();
error DividendsAlreadyClaimedForToken(uint256 tokenId);
error TokenNotOwnedByAccount();

contract DividendsTreasury is Ownable {
    event DividendsClaimed(address indexed account, uint256 indexed tokenId, uint256 amount);

    struct DividendRound {
        uint256 totalClaimable;
        uint256 totalClaimed;
        uint256 startBlock;
        uint256 endBlock;
        mapping(uint256 => bool) hasClaimedForToken;
        mapping(uint256 => uint256) claimedAmountForToken;
    }

    DividendRound[] public dividendRounds;
    uint256 public treasuryBalance;

    address public immutable projectTreasury;
    IERC721 public immutable buildingBlocksCollection;
    RarityOracle public immutable rarityOracle;
    uint256 public immutable blockTimeInSeconds;

    constructor(
        address _projectTreasury,
        IERC721 _buildingBlocksCollection,
        RarityOracle _rarityOracle,
        uint256 _blockTimeInSeconds
    ) {
        projectTreasury = _projectTreasury;
        buildingBlocksCollection = _buildingBlocksCollection;
        rarityOracle = _rarityOracle;
        blockTimeInSeconds = _blockTimeInSeconds;
    }

    modifier whenLastRoundIsClosed() {
        if (dividendRounds[dividendRounds.length - 1].endBlock > block.number) {
            revert LastRoundNotClosed();
        }
        _;
    }

    modifier whenLastRoundIsOpen() {
        if (dividendRounds[dividendRounds.length - 1].endBlock <= block.number) {
            revert LastRoundAlreadyClosed();
        }
        _;
    }

    function issueDividends(uint256 amount, uint256 durationInSeconds) public onlyOwner whenLastRoundIsClosed {
        if (amount > treasuryBalance) {
            revert DividendsAmountExceedsBalance();
        }

        if (durationInSeconds / blockTimeInSeconds == 0) {
            revert DurationCannotBeZero();
        }

        treasuryBalance -= amount;

        DividendRound storage newRound = dividendRounds.push();
        newRound.totalClaimable = amount;
        newRound.startBlock = block.number;
        newRound.endBlock = block.number + durationInSeconds / blockTimeInSeconds;
    }

    function getAccountTokens(address account) public view returns (uint256[] memory) {
        uint256 tokenCount = buildingBlocksCollection.balanceOf(account);
        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = IERC721Enumerable(address(buildingBlocksCollection)).tokenOfOwnerByIndex(account, i);
        }

        return tokens;
    }

    function calculateDividendsForAccount(address account, uint256 roundIndex) public view returns (uint256) {
        uint256[] memory tokens = getAccountTokens(account);
        uint256 totalDividends = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            totalDividends += rarityOracle.rarityOf(tokenId);
        }
        totalDividends *= dividendRounds[roundIndex].totalClaimable;
        totalDividends /= rarityOracle.raritiesSum();

        return totalDividends;
    }

    function calculateDividendsForToken(uint256 tokenId, uint256 roundIndex) public view returns (uint256) {
        uint256 totalDividends = rarityOracle.rarityOf(tokenId);
        totalDividends *= dividendRounds[roundIndex].totalClaimable;
        totalDividends /= rarityOracle.raritiesSum();

        return totalDividends;
    }

    function claimDividendsForToken(uint256 tokenId) public whenLastRoundIsOpen {
        uint256 roundIndex = dividendRounds.length - 1;
        if (dividendRounds[roundIndex].hasClaimedForToken[tokenId]) {
            revert DividendsAlreadyClaimedForToken(tokenId);
        }

        if (msg.sender != buildingBlocksCollection.ownerOf(tokenId)) {
            revert TokenNotOwnedByAccount();
        }

        uint256 dividends = calculateDividendsForToken(tokenId, roundIndex);
        treasuryBalance -= dividends;
        dividendRounds[roundIndex].totalClaimed += dividends;
        dividendRounds[roundIndex].hasClaimedForToken[tokenId] = true;
        dividendRounds[roundIndex].claimedAmountForToken[tokenId] = dividends;

        if (dividendRounds[roundIndex].totalClaimed == dividendRounds[roundIndex].totalClaimable) {
            dividendRounds[roundIndex].endBlock = block.number;
        }

        (bool success, ) = msg.sender.call{ value: dividends }("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit DividendsClaimed(msg.sender, tokenId, dividends);
    }

    function claimDividends() public whenLastRoundIsOpen {
        uint256 roundIndex = dividendRounds.length - 1;
        uint256[] memory tokens = getAccountTokens(msg.sender);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            if (dividendRounds[roundIndex].hasClaimedForToken[tokenId]) {
                continue;
            }
            claimDividendsForToken(tokenId);
        }
    }

    function terminateDividendRound(uint256 roundIndex) public onlyOwner whenLastRoundIsOpen {
        dividendRounds[roundIndex].endBlock = block.number;
    }

    function withdraw(uint256 amount) public onlyOwner {
        if (amount > treasuryBalance) {
            revert DividendsAmountExceedsBalance();
        }

        treasuryBalance -= amount;

        (bool success, ) = projectTreasury.call{ value: amount }("");
        if (!success) {
            revert WithdrawalFailed();
        }
    }

    function withdrawUnclaimed() public onlyOwner whenLastRoundIsClosed {
        uint256 totalUnclaimed = address(this).balance - treasuryBalance;

        (bool success, ) = projectTreasury.call{ value: totalUnclaimed }("");
        if (!success) {
            revert WithdrawalFailed();
        }
    }

    function waiveUnclaimed() public onlyOwner whenLastRoundIsClosed {
        treasuryBalance = address(this).balance;
    }

    receive() external payable {
        treasuryBalance += msg.value;
    }
}
