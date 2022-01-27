require('@nomiclabs/hardhat-ethers');

const hre = require('hardhat');
const { expect } = require("chai");
const ORDERBOOK_DEX = "OrderbookDEX";
const LINK_TOKEN = "LINKToken";
const USDT_TOKEN = "USDTToken";

before("Deploy OrderbookDEX and some tokens", async () => {
  // Prepare parameters
  const [deployer, operator, buyer, seller] = await hre.ethers.getSigners();
  this.deployer = deployer;
  this.operator = operator;
  this.buyer = buyer;
  this.seller = seller;

  // Deploy USDTToken contract
  this.usdtFactory = await hre.ethers.getContractFactory(USDT_TOKEN);
  this.usdtContract = await this.usdtFactory.deploy();
  await this.usdtContract.deployed();

  // Deploy LINKToken contract
  this.linkFactory = await hre.ethers.getContractFactory(LINK_TOKEN);
  this.linkContract = await this.linkFactory.deploy();
  await this.linkContract.deployed();

  // Deploy OrderbookDEX contract
  this.dexFactory = await hre.ethers.getContractFactory(ORDERBOOK_DEX);
  this.dexContract = await this.dexFactory.deploy(this.usdtContract.address);
  await this.dexContract.deployed();
});

describe("Test OrderbookDEX", () => {
  it("Mint some tokens to a buyer and a seller", async () => {
    await this.usdtFactory
      .connect(this.buyer)
      .attach(this.usdtContract.address)
      .faucet("200000000000000000000000");
    await this.usdtFactory
      .connect(this.seller)
      .attach(this.usdtContract.address)
      .faucet("200000000000000000000000");
    await this.linkFactory
      .connect(this.buyer)
      .attach(this.linkContract.address)
      .faucet("200000000000000000000000");
    await this.linkFactory
      .connect(this.seller)
      .attach(this.linkContract.address)
      .faucet("200000000000000000000000");
    let buyerUsdtBalance = await this.usdtContract.balanceOf(this.buyer.address);
    let buyerLinkBalance = await this.linkContract.balanceOf(this.buyer.address);
    let sellerUsdtBalance = await this.usdtContract.balanceOf(this.seller.address);
    let sellerLinkBalance = await this.linkContract.balanceOf(this.seller.address);
    expect(buyerUsdtBalance.toString()).to.equal("200000000000000000000000");
    expect(buyerLinkBalance.toString()).to.equal("200000000000000000000000");
    expect(sellerUsdtBalance.toString()).to.equal("200000000000000000000000");
    expect(sellerLinkBalance.toString()).to.equal("200000000000000000000000");
  });

  it("Set operator", async () => {
    await this.dexFactory
      .connect(this.deployer)
      .attach(this.dexContract.address)
      .setOperator(this.operator.address, true);
    let usdtAddr = await this.dexContract.USDT();
    expect(usdtAddr).to.equal(this.usdtContract.address);
  });

  it("Set currencies", async () => {
    await this.dexFactory
      .connect(this.operator)
      .attach(this.dexContract.address)
      .setCurrency(this.linkContract.address);
    let numSupportedCurrencies = await this.dexContract.getNumSupportedCurrencies();
    let currency = await this.dexContract.supportedCurrencies(0);
    expect(numSupportedCurrencies.toString()).to.equal("1");
    expect(currency).to.equal(this.linkContract.address);
  });

  it("A buyer deposits some USDT", async () => {
    await this.usdtFactory
      .connect(this.buyer)
      .attach(this.usdtContract.address)
      .approve(this.dexContract.address, 50000);
    await this.dexFactory
      .connect(this.buyer)
      .attach(this.dexContract.address)
      .deposit(this.usdtContract.address, 50000);
    let balance = await this.dexContract.getBalance(this.buyer.address, this.usdtContract.address);
    expect(balance.toString()).to.equal("50000");
  });

  it("A seller deposits some LINK", async () => {
    await this.linkFactory
      .connect(this.seller)
      .attach(this.linkContract.address)
      .approve(this.dexContract.address, 8000);
    await this.dexFactory
      .connect(this.seller)
      .attach(this.dexContract.address)
      .deposit(this.linkContract.address, 8000);
    let balance = await this.dexContract.getBalance(this.seller.address, this.linkContract.address);
    expect(balance.toString()).to.equal("8000");
  });

  it("A buyer wants to buy 1 LINK at the rate of $50/LINK", async () => {
    await this.dexFactory
      .connect(this.buyer)
      .attach(this.dexContract.address)
      .placeBuyOrder(this.linkContract.address, 1, 50);
    let buyOrders = await this.dexContract.getOrders(this.linkContract.address, 0);
    expect(buyOrders.length).to.equal(1);
    expect(buyOrders[0]?.amount?.toString()).to.equal("1");
    expect(buyOrders[0]?.filled?.toString()).to.equal("0");
    expect(buyOrders[0]?.price?.toString()).to.equal("50");
  });

  it("A seller wants to sell 1 LINK at the rate of $60/LINK", async () => {
    await this.dexFactory
      .connect(this.seller)
      .attach(this.dexContract.address)
      .placeSellOrder(this.linkContract.address, 1, 60);
    let buyOrders = await this.dexContract.getOrders(this.linkContract.address, 0);
    let sellOrders = await this.dexContract.getOrders(this.linkContract.address, 1);
    expect(buyOrders.length).to.equal(1);
    expect(buyOrders[0]?.amount?.toString()).to.equal("1");
    expect(buyOrders[0]?.filled?.toString()).to.equal("0");
    expect(buyOrders[0]?.price?.toString()).to.equal("50");
    expect(sellOrders.length).to.equal(1);
    expect(sellOrders[0]?.amount?.toString()).to.equal("1");
    expect(sellOrders[0]?.filled?.toString()).to.equal("0");
    expect(sellOrders[0]?.price?.toString()).to.equal("60");
  });

  it("A seller wants to sell 1 LINK at the rate of $45/LINK", async () => {
    await this.dexFactory
      .connect(this.seller)
      .attach(this.dexContract.address)
      .placeSellOrder(this.linkContract.address, 1, 45);
    let buyOrders = await this.dexContract.getOrders(this.linkContract.address, 0);
    let sellOrders = await this.dexContract.getOrders(this.linkContract.address, 1);
    expect(buyOrders.length).to.equal(0);
    expect(sellOrders.length).to.equal(1);
    expect(sellOrders[0]?.amount?.toString()).to.equal("1");
    expect(sellOrders[0]?.filled?.toString()).to.equal("0");
    expect(sellOrders[0]?.price?.toString()).to.equal("60");
  });

  it("A seller wants to sell 10 LINK at the rate of $35/LINK", async () => {
    await this.dexFactory
      .connect(this.seller)
      .attach(this.dexContract.address)
      .placeSellOrder(this.linkContract.address, 10, 35);
    let buyOrders = await this.dexContract.getOrders(this.linkContract.address, 0);
    let sellOrders = await this.dexContract.getOrders(this.linkContract.address, 1);
    expect(buyOrders.length).to.equal(0);
    expect(sellOrders.length).to.equal(2);
    expect(sellOrders[0]?.amount?.toString()).to.equal("10");
    expect(sellOrders[0]?.filled?.toString()).to.equal("0");
    expect(sellOrders[0]?.price?.toString()).to.equal("35");
    expect(sellOrders[1]?.amount?.toString()).to.equal("1");
    expect(sellOrders[1]?.filled?.toString()).to.equal("0");
    expect(sellOrders[1]?.price?.toString()).to.equal("60");
  });

  it("A seller wants to sell 7 LINK at the rate of $55/LINK", async () => {
    await this.dexFactory
      .connect(this.seller)
      .attach(this.dexContract.address)
      .placeSellOrder(this.linkContract.address, 7, 55);
    let buyOrders = await this.dexContract.getOrders(this.linkContract.address, 0);
    let sellOrders = await this.dexContract.getOrders(this.linkContract.address, 1);
    expect(buyOrders.length).to.equal(0);
    expect(sellOrders.length).to.equal(3);
    expect(sellOrders[0]?.amount?.toString()).to.equal("10");
    expect(sellOrders[0]?.filled?.toString()).to.equal("0");
    expect(sellOrders[0]?.price?.toString()).to.equal("35");
    expect(sellOrders[1]?.amount?.toString()).to.equal("7");
    expect(sellOrders[1]?.filled?.toString()).to.equal("0");
    expect(sellOrders[1]?.price?.toString()).to.equal("55");
    expect(sellOrders[2]?.amount?.toString()).to.equal("1");
    expect(sellOrders[2]?.filled?.toString()).to.equal("0");
    expect(sellOrders[2]?.price?.toString()).to.equal("60");
  });

  it("A buyer wants to buy 14 LINK at the rate of $57/LINK", async () => {
    await this.dexFactory
      .connect(this.buyer)
      .attach(this.dexContract.address)
      .placeBuyOrder(this.linkContract.address, 14, 57);
    let buyOrders = await this.dexContract.getOrders(this.linkContract.address, 0);
    let sellOrders = await this.dexContract.getOrders(this.linkContract.address, 1);
    expect(buyOrders.length).to.equal(0);
    expect(sellOrders.length).to.equal(2);
    expect(sellOrders[0]?.amount?.toString()).to.equal("7");
    expect(sellOrders[0]?.filled?.toString()).to.equal("4");
    expect(sellOrders[0]?.price?.toString()).to.equal("55");
    expect(sellOrders[1]?.amount?.toString()).to.equal("1");
    expect(sellOrders[1]?.filled?.toString()).to.equal("0");
    expect(sellOrders[1]?.price?.toString()).to.equal("60");
  });

  it("A buyer wants to buy 8 LINK at the rate of $58/LINK", async () => {
    await this.dexFactory
      .connect(this.buyer)
      .attach(this.dexContract.address)
      .placeBuyOrder(this.linkContract.address, 8, 58);
    let buyOrders = await this.dexContract.getOrders(this.linkContract.address, 0);
    let sellOrders = await this.dexContract.getOrders(this.linkContract.address, 1);
    expect(buyOrders.length).to.equal(1);
    expect(sellOrders.length).to.equal(1);
    expect(buyOrders[0]?.amount?.toString()).to.equal("8");
    expect(buyOrders[0]?.filled?.toString()).to.equal("3");
    expect(buyOrders[0]?.price?.toString()).to.equal("58");
    expect(sellOrders[0]?.amount?.toString()).to.equal("1");
    expect(sellOrders[0]?.filled?.toString()).to.equal("0");
    expect(sellOrders[0]?.price?.toString()).to.equal("60");
  });
});

// Run: npx hardhat test ./test/test-orderbook-dex.js