// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { BaseNFT } from "./BaseNFT.sol";
import { RarityOracle } from "./interfaces/RarityOracle.sol";

error RaritiesLengthMismatch();
error NonExistentTokenId(uint256 tokenId);

contract BuildingBlocksNFT is BaseNFT, RarityOracle {
    uint256[] private _rarities;
    uint256 private _raritiesSum;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _reservedSupply,
        uint256 _mintPrice,
        address _dividendsTreasury,
        address _projectTreasury,
        uint256 _dividendsShareBasisPoints
    )
        BaseNFT(
            _name,
            _symbol,
            _maxSupply,
            _reservedSupply,
            _mintPrice,
            _dividendsTreasury,
            _projectTreasury,
            _dividendsShareBasisPoints
        )
    {}

    function revealRarities(uint256[] calldata rarities) public onlyOwner {
        if (rarities.length != maxSupply) {
            revert RaritiesLengthMismatch();
        }

        _rarities = rarities;
        _raritiesSum = 0;
        for (uint256 i = 0; i < rarities.length; i++) {
            _raritiesSum += rarities[i];
        }
    }

    function rarityOf(uint256 tokenId) public view virtual override returns (uint256) {
        if (tokenId >= _rarities.length) {
            revert NonExistentTokenId(tokenId);
        }

        return _rarities[tokenId];
    }

    function raritiesSum() public view virtual override returns (uint256) {
        return _raritiesSum;
    }
}
