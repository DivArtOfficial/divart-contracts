// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import "./ExclusiveWhitelistable.sol";
import "./Whitelistable.sol";
import "ERC721A/extensions/ERC721AQueryable.sol";
import "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/Pausable.sol";
import "openzeppelin-contracts/contracts/utils/Counters.sol";

error ZeroAddress();
error ZeroMaxSupply();
error ReservedExceedsMaxSupply();
error DividentsShareBPTooHigh();
error ExclusiveWhitelistMintingNotLive();
error ExclusiveWhitelistMintingLive();
error WhitelistMintingNotLive();
error WhitelistMintingLive();
error PublicMintingNotLive();
error PublicMintingLive();
error ClaimBeforeMintingStarted();
error MintPriceNotPaid();
error MaxSupplyReached();
error MintingAlreadyStarted();
error PastTimestamp();
error EmptyURI();
error TransferFailed(address recipient);
error InvalidAmount(uint256 amount);
error NonExistentTokenId(uint256 tokenId);
error ArrayLengthMismatch();

contract BaseNFT is ERC721AQueryable, ERC2981, Ownable, Pausable, ExclusiveWhitelistable, Whitelistable {
    using Counters for Counters.Counter;

    uint256 public immutable maxSupply;
    uint256 public immutable reservedSupply;
    uint256 public immutable exclusiveWhitelistMintPrice;
    uint256 public immutable whitelistMintPrice;
    uint256 public immutable publicMintPrice;
    address public immutable dividendsTreasury;
    address public immutable projectTreasury;
    uint256 public immutable dividendsSharePerExclusiveWhitelistMint;
    uint256 public immutable dividendsSharePerWhitelistMint;
    uint256 public immutable dividendsSharePerPublicMint;
    uint256 public immutable projectSharePerExclusiveWhitelistMint;
    uint256 public immutable projectSharePerWhitelistMint;
    uint256 public immutable projectSharePerPublicMint;

    uint256 public exclusiveWhitelistSupply;
    uint256 public whitelistSupply;
    uint256 public mintStartTimestamp;
    string public baseURI;

    modifier whenMintingNotStarted() {
        if (block.timestamp >= mintStartTimestamp) {
            revert MintingAlreadyStarted();
        }
        _;
    }

    modifier whenExclusiveWhitelistMintingLive() {
        if (!isExclusiveWhitelistMintingLive()) {
            revert ExclusiveWhitelistMintingNotLive();
        }
        _;
    }

    modifier whenExclusiveWhitelistMintingNotLive() {
        if (isExclusiveWhitelistMintingLive()) {
            revert ExclusiveWhitelistMintingLive();
        }
        _;
    }

    modifier whenWhitelistMintingLive() {
        if (!isWhitelistMintingLive()) {
            revert WhitelistMintingNotLive();
        }
        _;
    }

    modifier whenWhitelistMintingNotLive() {
        if (isWhitelistMintingLive()) {
            revert WhitelistMintingLive();
        }
        _;
    }

    modifier whenPublicMintingLive() {
        if (!isPublicMintingLive()) {
            revert PublicMintingNotLive();
        }
        _;
    }

    modifier whenPublicMintingNotLive() {
        if (isPublicMintingLive()) {
            revert PublicMintingLive();
        }
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _reservedSupply,
        uint256 _exclusiveWhitelistMintPrice,
        uint256 _whitelistMintPrice,
        uint256 _publicMintPrice,
        address _dividendsTreasury,
        address _projectTreasury,
        uint256 _dividendsShareBasisPoints,
        uint256 _mintStartTimestamp
    ) ERC721A(_name, _symbol) {
        if (_dividendsTreasury == address(0) || _projectTreasury == address(0)) {
            revert ZeroAddress();
        }

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
        exclusiveWhitelistMintPrice = _exclusiveWhitelistMintPrice;
        whitelistMintPrice = _whitelistMintPrice;
        publicMintPrice = _publicMintPrice;
        dividendsTreasury = _dividendsTreasury;
        projectTreasury = _projectTreasury;
        dividendsSharePerExclusiveWhitelistMint = (_exclusiveWhitelistMintPrice * _dividendsShareBasisPoints) / 1e4;
        dividendsSharePerWhitelistMint = (_whitelistMintPrice * _dividendsShareBasisPoints) / 1e4;
        dividendsSharePerPublicMint = (_publicMintPrice * _dividendsShareBasisPoints) / 1e4;
        projectSharePerExclusiveWhitelistMint = _exclusiveWhitelistMintPrice - dividendsSharePerExclusiveWhitelistMint;
        projectSharePerWhitelistMint = _whitelistMintPrice - dividendsSharePerWhitelistMint;
        projectSharePerPublicMint = _publicMintPrice - dividendsSharePerPublicMint;

        mintStartTimestamp = _mintStartTimestamp;

        if (_reservedSupply > 0) {
            _mint(projectTreasury, _reservedSupply);
        }
    }

    function isExclusiveWhitelistMintingLive() public view returns (bool) {
        return block.timestamp >= mintStartTimestamp && block.timestamp < mintStartTimestamp + 1 days;
    }

    function isWhitelistMintingLive() public view returns (bool) {
        return block.timestamp >= mintStartTimestamp + 1 days && block.timestamp < mintStartTimestamp + 2 days;
    }

    function isPublicMintingLive() public view returns (bool) {
        return block.timestamp >= mintStartTimestamp + 2 days;
    }

    function exclusiveWhitelistMint(address recipient, uint256 amount)
        public
        payable
        whenNotPaused
        whenExclusiveWhitelistMintingLive
        onlyExclusiveWhitelisted
    {
        if (amount == 0 || amount * 2 > maxSupply) {
            revert InvalidAmount(amount);
        }

        uint256 totalMintPrice = exclusiveWhitelistMintPrice * amount;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        if (totalSupply() + amount * 2 > maxSupply) {
            revert MaxSupplyReached();
        }

        _removeExclusiveWhitelistSpots(msg.sender, amount);
        exclusiveWhitelistSupply -= amount;
        _mint(recipient, amount * 2);

        uint256 dividendsShareTotal = dividendsSharePerExclusiveWhitelistMint * amount;
        (bool success, ) = address(dividendsTreasury).call{ value: dividendsShareTotal }("");
        if (!success) {
            revert TransferFailed(address(dividendsTreasury));
        }

        uint256 projectShareTotal = projectSharePerExclusiveWhitelistMint * amount;
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

    function whitelistMint(address recipient, uint256 amount)
        public
        payable
        whenNotPaused
        whenWhitelistMintingLive
        onlyWhitelisted
    {
        if (amount == 0 || amount > maxSupply) {
            revert InvalidAmount(amount);
        }

        uint256 totalMintPrice = whitelistMintPrice * amount;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        if (totalSupply() + amount > maxSupply) {
            revert MaxSupplyReached();
        }

        _removeWhitelistSpots(msg.sender, amount);
        whitelistSupply -= amount;
        _mint(recipient, amount);

        uint256 dividendsShareTotal = dividendsSharePerWhitelistMint * amount;
        (bool success, ) = address(dividendsTreasury).call{ value: dividendsShareTotal }("");
        if (!success) {
            revert TransferFailed(address(dividendsTreasury));
        }

        uint256 projectShareTotal = projectSharePerWhitelistMint * amount;
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

    function publicMint(address recipient, uint256 amount) public payable whenNotPaused whenPublicMintingLive {
        if (amount == 0 || amount > maxSupply) {
            revert InvalidAmount(amount);
        }

        uint256 totalMintPrice = publicMintPrice * amount;
        if (msg.value < totalMintPrice) {
            revert MintPriceNotPaid();
        }

        if (totalSupply() + amount + exclusiveWhitelistSupply * 2 > maxSupply) {
            revert MaxSupplyReached();
        }

        _mint(recipient, amount);

        uint256 dividendsShareTotal = dividendsSharePerPublicMint * amount;
        (bool success, ) = address(dividendsTreasury).call{ value: dividendsShareTotal }("");
        if (!success) {
            revert TransferFailed(address(dividendsTreasury));
        }

        uint256 projectShareTotal = projectSharePerPublicMint * amount;
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

    function claimUnmintedExclusiveWhitelistSpots() public onlyOwner whenExclusiveWhitelistMintingNotLive {
        if (block.timestamp < mintStartTimestamp) {
            revert ClaimBeforeMintingStarted();
        }

        _mint(projectTreasury, exclusiveWhitelistSupply * 2);
        exclusiveWhitelistSupply = 0;
    }

    function setMintStartTimestamp(uint256 _mintStartTimestamp) public onlyOwner whenMintingNotStarted {
        if (_mintStartTimestamp <= block.timestamp) {
            revert PastTimestamp();
        }

        mintStartTimestamp = _mintStartTimestamp;
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

    function addExclusiveWhitelistSpots(address _addr, uint256 _amount) public onlyOwner whenMintingNotStarted {
        if (totalSupply() + (_amount + exclusiveWhitelistSupply) * 2 + whitelistSupply > maxSupply) {
            revert MaxSupplyReached();
        }

        exclusiveWhitelistSupply += _amount;
        _addExclusiveWhitelistSpots(_addr, _amount);
    }

    function addExclusiveWhitelistSpots(address[] calldata _addresses, uint256[] calldata _amounts) public onlyOwner {
        if (_addresses.length != _amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < _addresses.length; i++) {
            addExclusiveWhitelistSpots(_addresses[i], _amounts[i]);
        }
    }

    function removeExclusiveWhitelistSpots(address _addr, uint256 _amount) public onlyOwner whenMintingNotStarted {
        _removeExclusiveWhitelistSpots(_addr, _amount);
        exclusiveWhitelistSupply -= _amount;
    }

    function clearExclusiveWhitelistSpots(address _addr) public onlyOwner whenMintingNotStarted {
        exclusiveWhitelistSupply -= exclusiveWhitelistSpots[_addr];
        _clearExclusiveWhitelistSpots(_addr);
    }

    function addWhitelistSpots(address _addr, uint256 _amount) public onlyOwner whenMintingNotStarted {
        if (totalSupply() + _amount + exclusiveWhitelistSupply * 2 + whitelistSupply > maxSupply) {
            revert MaxSupplyReached();
        }

        whitelistSupply += _amount;
        _addWhitelistSpots(_addr, _amount);
    }

    function addWhitelistSpots(address[] calldata _addresses, uint256[] calldata _amounts) public onlyOwner {
        if (_addresses.length != _amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < _addresses.length; i++) {
            addWhitelistSpots(_addresses[i], _amounts[i]);
        }
    }

    function removeWhitelistSpots(address _addr, uint256 _amount) public onlyOwner whenMintingNotStarted {
        _removeWhitelistSpots(_addr, _amount);
        whitelistSupply -= _amount;
    }

    function clearWhitelistSpots(address _addr) public onlyOwner whenMintingNotStarted {
        whitelistSupply -= whitelistSpots[_addr];
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
