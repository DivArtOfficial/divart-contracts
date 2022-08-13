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
        uint256 maxSupply;
        uint256 mintPrice;
        string name;
        uint256 projectRoyaltyShares;
        uint256 reservedSupply;
        uint96 royaltyBasisPoints;
        string symbol;
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
            config.buildingBlocks.name,
            config.buildingBlocks.symbol,
            config.buildingBlocks.maxSupply,
            config.buildingBlocks.reservedSupply,
            config.buildingBlocks.mintPrice,
            address(dividendsTreasury),
            config.projectTreasury,
            config.buildingBlocks.dividendsShareBasisPoints,
            config.buildingBlocks.royaltyBasisPoints,
            config.buildingBlocks.dividendsRoyaltyShares,
            config.buildingBlocks.projectRoyaltyShares
        );

        dividendsTreasury.initialize(address(buildingBlocksNFT), RarityOracle(buildingBlocksNFT));

        vm.stopBroadcast();
    }
}
