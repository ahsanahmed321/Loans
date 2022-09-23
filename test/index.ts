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

    // Minting USDT on accounts
    await USDTtokenContract.mint(
      ethers.utils.parseEther("10000"),
      accounts[0].address
    );

    await USDTtokenContract.mint(
      ethers.utils.parseEther("10000"),
      accounts[1].address
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

  it("first and second account hold the USDT", async () => {
    const usdtBalanceAccount1 = await USDTtokenContract.balanceOf(
      accounts[0].address
    );
    const usdtBalanceAccount2 = await USDTtokenContract.balanceOf(
      accounts[1].address
    );

    expect(Number(ethers.utils.formatEther(usdtBalanceAccount1)) > 0);
    expect(Number(ethers.utils.formatEther(usdtBalanceAccount2)) > 0);
  });

  it("Lend USDT ", async () => {
    LPtokenContract.connect(accounts[0]);
    const LPTokenBalance = await LPtokenContract.balanceOf(accounts[0].address);

    expect(Number(ethers.utils.formatEther(LPTokenBalance)) > 400);
  });
});
