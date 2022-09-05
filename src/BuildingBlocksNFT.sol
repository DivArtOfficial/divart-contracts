// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { BaseNFT } from "./BaseNFT.sol";
import { RarityOracle } from "./interfaces/RarityOracle.sol";
import { PaymentSplitter } from "./PaymentSplitter.sol";

error RaritiesLengthMismatch();
error NonExistentTokenId(uint256 tokenId);

contract BuildingBlocksNFT is BaseNFT, RarityOracle {
    struct BuildingBlocksConfig {
        string name;
        string symbol;
        uint256 maxSupply;
        uint256 reservedSupply;
        uint256 exclusiveWhitelistMintPrice;
        uint256 whitelistMintPrice;
        uint256 publicMintPrice;
        address dividendsTreasury;
        address projectTreasury;
        uint256 dividendsShareBasisPoints;
        uint256 mintingStartTimestamp;
        uint96 royaltyBasisPoints;
        uint256 dividendsRoyaltyShares;
        uint256 projectRoyaltyShares;
    }

    PaymentSplitter public immutable PAYMENT_SPLITTER;

    uint256[] private _rarities;
    uint256 private _raritiesSum;

    constructor(BuildingBlocksConfig memory config)
        BaseNFT(
            config.name,
            config.symbol,
            config.maxSupply,
            config.reservedSupply,
            config.exclusiveWhitelistMintPrice,
            config.whitelistMintPrice,
            config.publicMintPrice,
            config.dividendsTreasury,
            config.projectTreasury,
            config.dividendsShareBasisPoints,
            config.mintingStartTimestamp
        )
    {
        address[] memory _payees = new address[](2);
        uint256[] memory _shares = new uint256[](2);

        _payees[0] = config.dividendsTreasury;
        _shares[0] = config.dividendsRoyaltyShares;

        _payees[1] = config.projectTreasury;
        _shares[1] = config.projectRoyaltyShares;

        PAYMENT_SPLITTER = new PaymentSplitter(_payees, _shares);
        super._setDefaultRoyalty(address(PAYMENT_SPLITTER), config.royaltyBasisPoints);
    }

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
