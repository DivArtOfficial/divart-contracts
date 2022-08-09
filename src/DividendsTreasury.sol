// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { RarityOracle } from "./interfaces/RarityOracle.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";
import { IERC721Enumerable } from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

error NotInitialized();
error AlreadyInitialized();
error LastRoundNotClosed();
error LastRoundNotOpen();
error ZeroDividendsAmount();
error DividendsAmountExceedsBalance();
error NullDuration();
error WithdrawalFailed();
error WithdrawalAmountExceedsBalance();
error DividendsAlreadyClaimedForToken(uint256 tokenId);
error TokenNotOwnedByAccount();

contract DividendsTreasury is Ownable {
    event DividendsClaimed(address indexed account, uint256 indexed tokenId, uint256 amount);

    struct DividendsRound {
        uint256 totalClaimable;
        uint256 totalClaimed;
        uint256 startTimestamp;
        uint256 endTimestamp;
    }

    DividendsRound[] private _dividendsRounds;

    uint256 public treasuryBalance;
    mapping(uint256 => mapping(uint256 => bool)) public hasClaimedForRoundForToken;
    mapping(uint256 => mapping(uint256 => uint256)) public claimedAmountForRoundForToken;

    address public immutable projectTreasury;

    address public buildingBlocksCollection;
    RarityOracle public rarityOracle;

    constructor(address _projectTreasury) {
        projectTreasury = _projectTreasury;
    }

    modifier whenLastRoundIsClosed() {
        uint256 pastRoundsCount = _dividendsRounds.length;
        if (pastRoundsCount > 0 && _dividendsRounds[pastRoundsCount - 1].endTimestamp > block.timestamp) {
            revert LastRoundNotClosed();
        }
        _;
    }

    modifier whenLastRoundIsOpen() {
        uint256 pastRoundsCount = _dividendsRounds.length;
        if (pastRoundsCount == 0 || _dividendsRounds[pastRoundsCount - 1].endTimestamp <= block.timestamp) {
            revert LastRoundNotOpen();
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

    function getDividendsRound(uint256 roundIndex) public view returns (DividendsRound memory) {
        return _dividendsRounds[roundIndex];
    }

    function getDividendsRoundsCount() public view returns (uint256) {
        return _dividendsRounds.length;
    }

    function getDividendsRounds() public view returns (DividendsRound[] memory) {
        return _dividendsRounds;
    }

    function issueDividends(uint256 amount, uint256 durationInSeconds)
        public
        onlyOwner
        whenInitialized
        whenLastRoundIsClosed
    {
        if (amount == 0) {
            revert ZeroDividendsAmount();
        }

        if (amount > treasuryBalance) {
            revert DividendsAmountExceedsBalance();
        }

        if (durationInSeconds == 0) {
            revert NullDuration();
        }

        treasuryBalance -= amount;

        DividendsRound storage newRound = _dividendsRounds.push();
        newRound.totalClaimable = amount;
        newRound.startTimestamp = block.timestamp;
        newRound.endTimestamp = block.timestamp + durationInSeconds;
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
        totalDividends *= _dividendsRounds[roundIndex].totalClaimable;
        totalDividends /= rarityOracle.raritiesSum();

        return totalDividends;
    }

    function calculateDividendsForToken(uint256 tokenId, uint256 roundIndex) public view returns (uint256) {
        uint256 totalDividends = rarityOracle.rarityOf(tokenId);
        totalDividends *= _dividendsRounds[roundIndex].totalClaimable;
        totalDividends /= rarityOracle.raritiesSum();

        return totalDividends;
    }

    function claimDividendsForToken(uint256 tokenId) public whenInitialized whenLastRoundIsOpen {
        uint256 roundIndex = _dividendsRounds.length - 1;
        if (hasClaimedForRoundForToken[roundIndex][tokenId]) {
            revert DividendsAlreadyClaimedForToken(tokenId);
        }

        if (msg.sender != IERC721(buildingBlocksCollection).ownerOf(tokenId)) {
            revert TokenNotOwnedByAccount();
        }

        uint256 dividends = calculateDividendsForToken(tokenId, roundIndex);
        _dividendsRounds[roundIndex].totalClaimed += dividends;
        hasClaimedForRoundForToken[roundIndex][tokenId] = true;
        claimedAmountForRoundForToken[roundIndex][tokenId] = dividends;

        if (_dividendsRounds[roundIndex].totalClaimed == _dividendsRounds[roundIndex].totalClaimable) {
            _dividendsRounds[roundIndex].endTimestamp = block.timestamp;
        }

        (bool success, ) = msg.sender.call{ value: dividends }("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit DividendsClaimed(msg.sender, tokenId, dividends);
    }

    function claimDividends() public whenInitialized whenLastRoundIsOpen {
        uint256 roundIndex = _dividendsRounds.length - 1;
        uint256[] memory tokens = getAccountTokens(msg.sender);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenId = tokens[i];
            if (hasClaimedForRoundForToken[roundIndex][tokenId]) {
                continue;
            }
            claimDividendsForToken(tokenId);
        }
    }

    function terminateDividendsRound() public onlyOwner whenLastRoundIsOpen {
        _dividendsRounds[_dividendsRounds.length - 1].endTimestamp = block.timestamp;
    }

    function withdraw(uint256 amount) public onlyOwner whenInitialized {
        if (amount > treasuryBalance) {
            revert WithdrawalAmountExceedsBalance();
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
