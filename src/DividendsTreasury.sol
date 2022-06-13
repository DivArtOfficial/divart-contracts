// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { RarityOracle } from "./interfaces/RarityOracle.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

error ZeroBlockTime();
error NotInitialized();
error AlreadyInitialized();
error LastRoundNotClosed();
error LastRoundAlreadyClosed();
error ZeroDividends();
error DividendsAmountExceedsBalance();
error NullDuration();
error WithdrawalFailed();
error DividendsAlreadyClaimedForToken(uint256 tokenId);
error TokenNotOwnedByAccount();

contract DividendsTreasury is Ownable {
    event DividendsClaimed(address indexed account, uint256 indexed tokenId, uint256 amount);

    struct DividendsRound {
        uint256 totalClaimable;
        uint256 totalClaimed;
        uint256 startBlock;
        uint256 endBlock;
        mapping(uint256 => bool) hasClaimedForToken;
        mapping(uint256 => uint256) claimedAmountForToken;
    }

    DividendsRound[] public dividendsRounds;
    uint256 public treasuryBalance;

    address public immutable projectTreasury;
    uint256 public immutable blockTimeInSeconds;

    address public buildingBlocksCollection;
    RarityOracle public rarityOracle;

    constructor(address _projectTreasury, uint256 _blockTimeInSeconds) {
        if (_blockTimeInSeconds == 0) {
            revert ZeroBlockTime();
        }

        projectTreasury = _projectTreasury;
        blockTimeInSeconds = _blockTimeInSeconds;
    }

    modifier whenLastRoundIsClosed() {
        if (dividendsRounds[dividendsRounds.length - 1].endBlock > block.number) {
            revert LastRoundNotClosed();
        }
        _;
    }

    modifier whenLastRoundIsOpen() {
        if (dividendsRounds[dividendsRounds.length - 1].endBlock <= block.number) {
            revert LastRoundAlreadyClosed();
        }
        _;
    }

    modifier whenInitialized() {
        if (buildingBlocksCollection == address(0) || address(rarityOracle) == address(0)) {
            revert NotInitialized();
        }
        _;
    }

    modifier whenNotInitialized() {
        if (buildingBlocksCollection != address(0) || address(rarityOracle) != address(0)) {
            revert AlreadyInitialized();
        }
        _;
    }

    function initialize(address _buildingBlocksCollection, RarityOracle _rarityOracle) public whenNotInitialized {
        buildingBlocksCollection = _buildingBlocksCollection;
        rarityOracle = _rarityOracle;
    }

    function issueDividends(uint256 amount, uint256 durationInSeconds)
        public
        onlyOwner
        whenInitialized
        whenLastRoundIsClosed
    {
        if (amount == 0) {
            revert ZeroDividends();
        }

        if (amount > treasuryBalance) {
            revert DividendsAmountExceedsBalance();
        }

        if (durationInSeconds / blockTimeInSeconds == 0) {
            revert NullDuration();
        }

        treasuryBalance -= amount;

        DividendsRound storage newRound = dividendsRounds.push();
        newRound.totalClaimable = amount;
        newRound.startBlock = block.number;
        newRound.endBlock = block.number + durationInSeconds / blockTimeInSeconds;
    }

    function getAccountTokens(address account) public view returns (uint256[] memory) {
        uint256 tokenCount = IERC721(buildingBlocksCollection).balanceOf(account);
        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = IERC721Enumerable(buildingBlocksCollection).tokenOfOwnerByIndex(account, i);
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
        totalDividends *= dividendsRounds[roundIndex].totalClaimable;
        totalDividends /= rarityOracle.raritiesSum();

        return totalDividends;
    }

    function calculateDividendsForToken(uint256 tokenId, uint256 roundIndex) public view returns (uint256) {
        uint256 totalDividends = rarityOracle.rarityOf(tokenId);
        totalDividends *= dividendsRounds[roundIndex].totalClaimable;
        totalDividends /= rarityOracle.raritiesSum();

        return totalDividends;
    }

    function claimDividendsForToken(uint256 tokenId) public whenInitialized whenLastRoundIsOpen {
        uint256 roundIndex = dividendsRounds.length - 1;
        if (dividendsRounds[roundIndex].hasClaimedForToken[tokenId]) {
            revert DividendsAlreadyClaimedForToken(tokenId);
        }

        if (msg.sender != IERC721(buildingBlocksCollection).ownerOf(tokenId)) {
            revert TokenNotOwnedByAccount();
        }

        uint256 dividends = calculateDividendsForToken(tokenId, roundIndex);
        treasuryBalance -= dividends;
        dividendsRounds[roundIndex].totalClaimed += dividends;
        dividendsRounds[roundIndex].hasClaimedForToken[tokenId] = true;
        dividendsRounds[roundIndex].claimedAmountForToken[tokenId] = dividends;

        if (dividendsRounds[roundIndex].totalClaimed == dividendsRounds[roundIndex].totalClaimable) {
            dividendsRounds[roundIndex].endBlock = block.number;
        }

        (bool success, ) = msg.sender.call{ value: dividends }("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit DividendsClaimed(msg.sender, tokenId, dividends);
    }

    function claimDividends() public whenInitialized whenLastRoundIsOpen {
        uint256 roundIndex = dividendsRounds.length - 1;
        uint256[] memory tokens = getAccountTokens(msg.sender);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            if (dividendsRounds[roundIndex].hasClaimedForToken[tokenId]) {
                continue;
            }
            claimDividendsForToken(tokenId);
        }
    }

    function terminateDividendsRound(uint256 roundIndex) public onlyOwner whenLastRoundIsOpen {
        dividendsRounds[roundIndex].endBlock = block.number;
    }

    function withdraw(uint256 amount) public onlyOwner whenInitialized {
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
