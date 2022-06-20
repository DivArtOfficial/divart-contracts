# divart-contracts
This repository holds the Solidity smart contracts for the DivArt project.

## About The Project
DivArt is a digital gallery project that aims to empower emerging talented artists in the NFT space. But worry not! There is also a place for you in our ecosystem if you are a collector or investor.

### For Artists
Get access to a modern NFT-based art gallery as a launchpad to bootstrap your artistic career.

### For Collectors
Immerse yourself in the world of NFT art, collect, and own artistic pieces crafted by promising young artists through our platform.

### For Investors
Have a chance to mint our exclusive and limited building blocks NFT collection that will give you access to a share of the platform's revenue as dividends for as long as you HODL. 

## Contracts
Please note that the following contracts have been written by choosing readability over gas efficiency, wherever possible, as DivArt is built on top of the KCC blockchain whose gas fees are negligible.

### BaseNFT.sol
OpenZeppelin's ERC721 NFT contract with a few additions on top:

- single and batch mint
- revenue split
- metadata reveal

### BuildingBlocksNFT.sol
Contract for the first NFT collection launched by DivArt. Inherits from BaseNFT and adds a few features on top:

- reveal the rarity of each NFT in the collection
- act as a rarity oracle for the dividend treasury to query NFT rarities

### DividendsTreasury.sol
Contract that will hold the share of the revenue destined to the building blocks NFT holders. The dividends shares claimable per token are determined using the token rarity as a weight. Functionalities to manage dividends rounds:

- issue dividends round
- claim dividends for a token held by an account
- claim dividends for all the tokens an account holds
- terminate dividends round
- withdraw or waive unclaimed dividends after the round ends

## License
AGPL-3.0
