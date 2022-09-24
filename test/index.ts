/* eslint-disable node/no-missing-import */
import { expect } from "chai";
import { ethers } from "hardhat";

import { Loans__factory, Loans, ERC20Token } from "../typechain";

const ERC20ABI = require("../artifacts/contracts/ERC20.sol/ERC20Token.json");

describe("Loans", function () {
  let accounts: any;
  let LoansContract: Loans;
  let USDTtokenContract: ERC20Token;
  let LPtokenContract: ERC20Token;

  beforeEach(async () => {
    // deploying all contracts
    accounts = await ethers.getSigners();

    LoansContract = await new Loans__factory(accounts[0]).deploy();

    const USDTtokenAddress = await LoansContract.usdt();
    USDTtokenContract = new ethers.Contract(
      USDTtokenAddress,
      ERC20ABI.abi,
      accounts[0]
    ) as ERC20Token;

    const LPtokenAddress = await LoansContract.lpToken();
    LPtokenContract = new ethers.Contract(
      LPtokenAddress,
      ERC20ABI.abi,
      accounts[0]
    ) as ERC20Token;

    // Minting USDT on account
    await USDTtokenContract.mint(
      ethers.utils.parseEther("10000"),
      accounts[0].address
    );

    // Providing Liquidity to Protocol
    await USDTtokenContract.increaseAllowance(
      LoansContract.address,
      ethers.utils.parseEther("10000")
    );

    await LoansContract.lend(ethers.utils.parseEther("5000"), {
      gasLimit: "550000",
    });
  });

  it("deploys a Loans, LPToken and USDT contracts", async () => {
    expect(LoansContract.address);
    expect(LPtokenContract.address);
    expect(USDTtokenContract.address);
  });

  it("first account hold the USDT", async () => {
    const usdtBalanceAccount = await USDTtokenContract.balanceOf(
      accounts[0].address
    );

    expect(Number(ethers.utils.formatEther(usdtBalanceAccount))).gt(0);
  });

  it("Protocol Hold the USDT ", async () => {
    const LPTokenBalance = await LPtokenContract.balanceOf(accounts[0].address);

    expect(Number(ethers.utils.formatEther(LPTokenBalance))).gt(0);
  });

  it("Borrow USDT", async () => {
    await LoansContract.connect(accounts[1]).borrow({
      gasLimit: "550000",
      value: ethers.utils.parseEther("0.5"),
    });

    const usdtBalanceAccount = await USDTtokenContract.balanceOf(
      accounts[1].address
    );

    expect(Number(ethers.utils.formatEther(usdtBalanceAccount))).gte(400);
  });

  it("Borrow USDT and then repay", async () => {
    const LoansContractWithUser = LoansContract.connect(accounts[1]);

    await LoansContractWithUser.borrow({
      gasLimit: "550000",
      value: ethers.utils.parseEther("0.5"),
    });

    await USDTtokenContract.connect(accounts[1]).increaseAllowance(
      LoansContract.address,
      ethers.utils.parseEther("10000")
    );

    await LoansContractWithUser.repay(ethers.utils.parseEther("200"), {
      gasLimit: "550000",
    });

    const usdtBalanceAccount = await USDTtokenContract.balanceOf(
      accounts[1].address
    );

    expect(Number(ethers.utils.formatEther(usdtBalanceAccount))).gte(200);
  });
});
