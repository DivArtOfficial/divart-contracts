// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

error MintPriceNotPaid();
error MaxSupplyReached();
error EmptyURI();
error TransferFailed(address recipient);
error InvalidAmount(uint256 amount);
error NonExistentTokenId(uint256 tokenId);

contract BaseNFT is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256[] private _rarities;
    uint256 private _raritiesSum;

    uint256 public immutable maxSupply;
    uint256 public immutable mintPrice;
    address public immutable dividendsTreasury;
    address public immutable projectTreasury;
    uint256 public immutable dividendsSharePerMint;
    uint256 public immutable projectSharePerMint;

    string public baseURI;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        address _dividendsTreasury,
        address _projectTreasury,
        uint256 _dividendsShareBasisPoints
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        dividendsTreasury = _dividendsTreasury;
        projectTreasury = _projectTreasury;
        dividendsSharePerMint = (_mintPrice * _dividendsShareBasisPoints) / 1e4;
        projectSharePerMint = mintPrice - dividendsSharePerMint;
    }

    function _mintTo(address recipient) internal {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(recipient, tokenId);
    }

    function mintTo(address recipient) public payable {
        if (msg.value < mintPrice) {
            revert MintPriceNotPaid();
        }

        if (totalSupply() >= maxSupply) {
            revert MaxSupplyReached();
        }

        _mintTo(recipient);

        (bool success, ) = address(dividendsTreasury).call{ value: dividendsSharePerMint }("");
        if (!success) {
            revert TransferFailed(address(dividendsTreasury));
        }

        (success, ) = address(projectTreasury).call{ value: projectSharePerMint }("");
        if (!success) {
            revert TransferFailed(address(projectTreasury));
        }

        uint256 excessPayment = msg.value - mintPrice;
        (success, ) = msg.sender.call{ value: excessPayment }("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function mintBatchTo(address recipient, uint256 amount) public payable {
        if (amount == 0) {
            revert InvalidAmount(0);
        }

        uint256 totalMintPrice = mintPrice * amount;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        if (totalSupply() + amount > maxSupply) {
            revert MaxSupplyReached();
        }

        for (uint256 i = 0; i < amount; i++) {
            _mintTo(recipient);
        }

        uint256 dividendsShareTotal = dividendsSharePerMint * amount;
        (bool success, ) = address(dividendsTreasury).call{ value: dividendsShareTotal }("");
        if (!success) {
            revert TransferFailed(address(dividendsTreasury));
        }

        uint256 projectShareTotal = projectSharePerMint * amount;
        (success, ) = address(projectTreasury).call{ value: projectShareTotal }("");
        if (!success) {
            revert TransferFailed(address(projectTreasury));
        }

        uint256 excessPayment = msg.value - totalMintPrice;
        (success, ) = address(msg.sender).call{ value: excessPayment }("");
        if (!success) {
            revert TransferFailed(msg.sender);
        }
    }

    function revealMetadata(string calldata uri) public onlyOwner {
        if (bytes(uri).length == 0) {
            revert EmptyURI();
        }

        baseURI = uri;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
