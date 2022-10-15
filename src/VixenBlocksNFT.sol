// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity =0.8.14;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

/// @custom:security-contact gilgames@heroesvale.com
contract VixenBlocksNFT is ERC721, ERC721Enumerable, ERC2981, ReentrancyGuard, Pausable, Ownable {
    uint256 public constant MAX_SUPPLY = 50;
    address public constant TREASURY = 0x078F778c631cf274B8FBD57a8d72B8273A49F7ee;

    uint256 public mintStartTimestamp;
    uint256 public mintPrice;
    string public baseURI;

    error MaxSupplyReached();
    error InvalidAmount();
    error MintPriceNotPaid();
    error MintingNotStarted();
    error NonExistentTokenId();
    error ArrayLengthMismatch();
    error RoyaltyTooHigh();
    error TransferFailed(address recipient);

    event MintPriceChanged(uint256 previousMintPrice, uint256 newMintPrice);
    event MintStartTimestampChanged(uint256 previousMintStartTimestamp, uint256 newMintStartTimestamp);
    event BaseURIChanged(string previousBaseURI, string newBaseURI);
    event Mint(address indexed minter, uint256 tokenId);

    constructor() ERC721("Vixen Blocks", "VB") {
        mintStartTimestamp = 1666008000; // 2022-10-17T12:00:00Z
        mintPrice = 7 ether;
        baseURI = "https://divart.io/api/v1/collections/vixen-blocks/metadata/";
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _mint(address to) private {
        uint256 tokenId = totalSupply() + 1;
        if (tokenId > MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        _safeMint(to, tokenId);
        emit Mint(msg.sender, tokenId);
    }

    function mint(uint256 amount) public payable whenNotPaused nonReentrant {
        if (block.timestamp < mintStartTimestamp) {
            revert MintingNotStarted();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        uint256 totalMintPrice = amount * mintPrice;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        for (uint256 i = 0; i < amount; i++) {
            _mint(msg.sender);
        }

        (bool success, ) = TREASURY.call{ value: totalMintPrice }("");
        if (!success) {
            revert TransferFailed(TREASURY);
        }

        uint256 excessPayment = msg.value - totalMintPrice;
        if (excessPayment == 0) {
            return;
        }

        (success, ) = msg.sender.call{ value: excessPayment }("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        }

        uint256[] memory tokens = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokens[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokens;
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        uint256 previousMintPrice = mintPrice;
        mintPrice = _mintPrice;
        emit MintPriceChanged(previousMintPrice, mintPrice);
    }

    function setMintStartTimestamp(uint256 _mintStartTimestamp) public onlyOwner {
        uint256 previousMintStartTimestamp = mintStartTimestamp;
        mintStartTimestamp = _mintStartTimestamp;
        emit MintStartTimestampChanged(previousMintStartTimestamp, mintStartTimestamp);
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        string memory previousBaseURI = baseURI;
        baseURI = baseURI_;
        emit BaseURIChanged(previousBaseURI, baseURI_);
    }

    function setDefaultRoyalty(address recipient, uint96 royaltyBps) public onlyOwner {
        if (royaltyBps > 1000) {
            revert RoyaltyTooHigh();
        }

        super._setDefaultRoyalty(recipient, royaltyBps);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{ value: balance }("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
