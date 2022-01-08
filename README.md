## About this project

This is a simple example of how an Orderbook DEX works. The Orderbook Algorithm is used to match buy orders and sell orders together in a sensible way.

## Project structure

### Solidity contracts

This project contains 3 contracts, which is placed in the `contracts` folder.

* `OrderbookDEX.sol`: This is the main contract of the project. It allows traders to deposit their tokens, withdraw their tokens, place a buy order and place a sell order.
* `USDTToken.sol`: This is the ERC20 contract of USDT token, which is a token created for testing and demo only. USDT is the main token of `OrderbookDEX`, which is used as an intermediary token to trade other tokens.
* `LINKToken.sol`: This is the ERC20 contract of LINK token, which is a token created for testing and demo only. In `OrderbookDEX`, LINK is traded using USDT.

### Deployment scripts

These are 3 JS scripts which are used to deploy the above contracts to blockchain. They are placed in `scripts` folder.

* `1-deploy-USDT.js` is used to deploy `USDTToken.sol`.
* `2-deploy-LINK.js` is used to deploy `LINKToken.sol`.
* `3-deploy-orderbook-dex.js` is used to deploy `OrderbookDEX.sol`.

After each deployment, the address of the deployed contract is automatically written to the `deploy.json` file, which is placed in the root folder of the project.

### Testing scripts

The `testOrderbookDEX.js`, which is placed in the `test` folder, is the JS file used to test the `OrderbookDEX.sol` contract. It contains 12 test cases which simulates the activities of placing buy and sell orders.

### Tools

This project uses Hardhat as a main tool to test and deploy smart contracts.

> npx hardhat run {path-to-scripts} --network {network-name}

> npx hardhat test {path-to-test-file}

### Results

In this project, those contracts are deployed to Binance Smart Chain Testnet, whose Chain ID is 97. These are the deployed contracts:

* [USDTToken contract](https://testnet.bscscan.com/address/0xF48A779a72340ac7826a8E3C8065398e0aa0e649#code)
* [LINKToken contract](https://testnet.bscscan.com/address/0x13E176B47B3A030FC7bDf3f30705c6c258bA2c93#code)
* [OrderbookDEX contract](https://testnet.bscscan.com/address/0xBa9662c75025001328186D920b1F0365b386Aa9d#code)