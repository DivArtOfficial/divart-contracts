// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.14;

interface RarityOracle {
    function rarityOf(uint256 tokenId) external view returns (uint256 rarity);

    function raritiesSum() external view returns (uint256);
}
