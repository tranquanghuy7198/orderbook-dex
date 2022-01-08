## About this project

This is a simple example of how an Orderbook DEX works. The Orderbook Algorithm is used to match buy orders and sell orders together in a sensible way.

## Project structure

### Solidity contracts

This project contains 3 contracts, which is placed in the `contracts` folder.

* `OrderbookDEX.sol`: This is the main contract of the project. It allows traders to deposit their tokens, withdraw their tokens, place a buy order and place a sell order.
* `USDTToken.sol`: This is the ERC20 contract of USDT token, which is a token created for testing and demo only. USDT is the main token of `OrderbookDEX`, which is used as an intermediary token to trade other tokens.
* `LINKToken.sol`: This is the ERC20 contract of LINK token, which is a token created for testing and demo only. In `OrderbookDEX`, LINK is traded using USDT.

### Deployment scripts

These are JS scripts which are used to deploy the above contracts to blockchain. They are placed in `scripts` folder.

* `1-deploy-USDT.js` is used to deploy `USDTToken.sol`.
* `2-deploy-LINK.js` is used to deploy `LINKToken.sol`.
* `3-deploy-orderbook-dex.js` is used to deploy `OrderbookDEX.sol`.

After each deployment, the address of the deployed contract is automatically written to the `deploy.json` file, which is placed in the root folder of the project.

In this project, those contracts are deployed to Binance Smart Chain Testnet, whose Chain ID is 97.

### Testing scripts

The `testOrderbookDEX.js` is the JS file used to test the `OrderbookDEX.sol` contract. It contains 12 test cases which simulates the activities of placing buy and sell orders.

### Tools

This project uses Hardhat as a main tool to test and deploy smart contracts.

> npx hardhat run {path-to-scripts} --network {network-name}

> npx hardhat test {path-to-test-file}