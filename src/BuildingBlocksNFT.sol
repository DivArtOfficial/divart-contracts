// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { BaseNFT } from "./BaseNFT.sol";
import { RarityOracle } from "./interfaces/RarityOracle.sol";
import { PaymentSplitter } from "./PaymentSplitter.sol";

error RaritiesLengthMismatch();
error NonExistentTokenId(uint256 tokenId);

contract BuildingBlocksNFT is BaseNFT, RarityOracle {
    PaymentSplitter public paymentSplitter;

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
        uint256 _dividendsShareBasisPoints,
        uint96 _royaltyBasisPoints,
        uint256 _dividendsRoyaltyShares,
        uint256 _projectRoyaltyShares
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
    {
        address[] memory _payees = new address[](2);
        uint256[] memory _shares = new uint256[](2);

        _payees[0] = _dividendsTreasury;
        _shares[0] = _dividendsRoyaltyShares;

        _payees[1] = _projectTreasury;
        _shares[1] = _projectRoyaltyShares;

        paymentSplitter = new PaymentSplitter(_payees, _shares);
        super._setDefaultRoyalty(address(paymentSplitter), _royaltyBasisPoints);
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
