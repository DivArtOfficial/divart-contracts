// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.14;

import "../src/DividendsTreasury.sol";
import "../src/BuildingBlocksNFT.sol";
import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

interface JsonParser {
    function parseJson(string calldata, string calldata) external returns (bytes memory);

    function parseJson(string calldata) external returns (bytes memory);
}

contract DeployGenesis is Test {
    using Strings for uint256;

    struct BuildingBlocksConfig {
        uint256 dividendsRoyaltyShares;
        uint256 dividendsShareBasisPoints;
        uint256 exclusiveWhitelistMintPrice;
        uint256 maxSupply;
        uint256 mintingStartTimestamp;
        string name;
        uint256 projectRoyaltyShares;
        uint256 publicMintPrice;
        uint256 reservedSupply;
        uint96 royaltyBasisPoints;
        string symbol;
        uint256 whitelistMintPrice;
    }

    struct Config {
        BuildingBlocksConfig buildingBlocks;
        address projectTreasury;
    }

    JsonParser constant jsonParser = JsonParser(address(vm));
    Config config;

    function setUp() public {
        string memory json = vm.readFile("config.json");
        string memory chainID = block.chainid.toString();
        string memory key = string.concat(".", chainID);
        bytes memory data = jsonParser.parseJson(json, key);
        config = abi.decode(data, (Config));
        assertEq(config.buildingBlocks.name, "DivArt Building Blocks Collection");
    }

    function run() external {
        vm.startBroadcast();

        DividendsTreasury dividendsTreasury = new DividendsTreasury(config.projectTreasury);

        BuildingBlocksNFT buildingBlocksNFT = new BuildingBlocksNFT(
            BuildingBlocksNFT.BuildingBlocksConfig({
                name: config.buildingBlocks.name,
                symbol: config.buildingBlocks.symbol,
                maxSupply: config.buildingBlocks.maxSupply,
                reservedSupply: config.buildingBlocks.reservedSupply,
                exclusiveWhitelistMintPrice: config.buildingBlocks.exclusiveWhitelistMintPrice,
                whitelistMintPrice: config.buildingBlocks.whitelistMintPrice,
                publicMintPrice: config.buildingBlocks.publicMintPrice,
                dividendsTreasury: address(dividendsTreasury),
                projectTreasury: config.projectTreasury,
                dividendsShareBasisPoints: config.buildingBlocks.dividendsShareBasisPoints,
                royaltyBasisPoints: config.buildingBlocks.royaltyBasisPoints,
                dividendsRoyaltyShares: config.buildingBlocks.dividendsRoyaltyShares,
                projectRoyaltyShares: config.buildingBlocks.projectRoyaltyShares,
                mintingStartTimestamp: config.buildingBlocks.mintingStartTimestamp
            })
        );

        dividendsTreasury.initialize(address(buildingBlocksNFT), RarityOracle(buildingBlocksNFT));

        vm.stopBroadcast();
    }
}
