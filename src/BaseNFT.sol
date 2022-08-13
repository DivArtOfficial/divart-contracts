// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import "./Whitelistable.sol";
import "ERC721A/extensions/ERC721AQueryable.sol";
import "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";
import "openzeppelin-contracts/contracts/utils/Multicall.sol";

error ZeroMaxSupply();
error ReservedExceedsMaxSupply();
error DividentsShareBPTooHigh();
error MintPriceNotPaid();
error MaxSupplyReached();
error EmptyURI();
error TransferFailed(address recipient);
error InvalidAmount(uint256 amount);
error NonExistentTokenId(uint256 tokenId);

contract BaseNFT is ERC721AQueryable, ERC2981, Ownable, Pausable, Whitelistable, Multicall {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256[] private _rarities;
    uint256 private _raritiesSum;

    uint256 public immutable maxSupply;
    uint256 public immutable reservedSupply;
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
        uint256 _reservedSupply,
        uint256 _mintPrice,
        address _dividendsTreasury,
        address _projectTreasury,
        uint256 _dividendsShareBasisPoints
    ) ERC721A(_name, _symbol) {
        if (_maxSupply == 0) {
            revert ZeroMaxSupply();
        }

        if (_reservedSupply > _maxSupply) {
            revert ReservedExceedsMaxSupply();
        }

        if (_dividendsShareBasisPoints > 1e4) {
            revert DividentsShareBPTooHigh();
        }

        maxSupply = _maxSupply;
        reservedSupply = _reservedSupply;
        mintPrice = _mintPrice;
        dividendsTreasury = _dividendsTreasury;
        projectTreasury = _projectTreasury;
        dividendsSharePerMint = (_mintPrice * _dividendsShareBasisPoints) / 1e4;
        projectSharePerMint = mintPrice - dividendsSharePerMint;

        if (_reservedSupply > 0) {
            _mint(projectTreasury, _reservedSupply);
        }
    }

    // function _mintTo(address recipient) internal {
    //     uint256 tokenId = _tokenIdCounter.current();
    //     _tokenIdCounter.increment();
    //     _safeMint(recipient, tokenId);
    // }

    // function mintTo(address recipient) public payable whenNotPaused onlyWhitelisted {
    //     if (msg.value < mintPrice) {
    //         revert MintPriceNotPaid();
    //     }
    //
    //     if (totalSupply() >= maxSupply) {
    //         revert MaxSupplyReached();
    //     }
    //
    //     _removeWhitelistSpots(msg.sender, 1);
    //     _mintTo(recipient);
    //
    //     (bool success, ) = address(dividendsTreasury).call{ value: dividendsSharePerMint }("");
    //     if (!success) {
    //         revert TransferFailed(address(dividendsTreasury));
    //     }
    //
    //     (success, ) = address(projectTreasury).call{ value: projectSharePerMint }("");
    //     if (!success) {
    //         revert TransferFailed(address(projectTreasury));
    //     }
    //
    //     uint256 excessPayment = msg.value - mintPrice;
    //     (success, ) = msg.sender.call{ value: excessPayment }("");
    //     if (!success) {
    //         revert TransferFailed(msg.sender);
    //     }
    // }

    function mint(address recipient, uint256 amount) public payable whenNotPaused onlyWhitelisted {
        if (amount == 0 || amount > maxSupply) {
            revert InvalidAmount(amount);
        }

        uint256 totalMintPrice = mintPrice * amount;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        if (totalSupply() + amount > maxSupply) {
            revert MaxSupplyReached();
        }

        _removeWhitelistSpots(msg.sender, amount);
        _mint(recipient, amount);

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
        if (excessPayment == 0) {
            return;
        }

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

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function addWhitelistSpots(address _addr, uint256 _amount) public onlyOwner {
        _addWhitelistSpots(_addr, _amount);
    }

    function removeWhitelistSpots(address _addr, uint256 _amount) public onlyOwner {
        _removeWhitelistSpots(_addr, _amount);
    }

    function clearWhitelistSpots(address _addr) public onlyOwner {
        _clearWhitelistSpots(_addr);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC721A, ERC721A, ERC2981)
        returns (bool)
    {
        // Supports the following `interfaceId`s:
        // - IERC165: 0x01ffc9a7
        // - IERC721: 0x80ac58cd
        // - IERC721Metadata: 0x5b5e139f
        // - IERC2981: 0x2a55205a
        return ERC721A.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }
}
