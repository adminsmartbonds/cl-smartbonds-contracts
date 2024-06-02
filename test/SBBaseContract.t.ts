import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("SBBaseContract", function () {
  const TOTAL_SUPPLY = 10000;

    // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployBaseContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, addr1, addr2 ] = await hre.ethers.getSigners(); // Get the number of fake addresses you need

    const baseContract = await hre.ethers.getContractFactory("SBBaseContract");
    const contract = await baseContract.deploy("SBBaseContract001", "SBBSE001", TOTAL_SUPPLY, );

    return { contract, owner, addr1, addr2 };
  }

  describe("Deployment", function () {
    it("Should deploy", async function () {
      const { contract, owner } = await loadFixture(deployBaseContract);

      expect(contract).not.to.be.null;
      expect(owner).not.to.be.null;
    });
  });
  describe("Execution", function() {
    it("Should be able to transfer tokens less than ", async function () {
      const { contract, owner, addr1 } = await loadFixture(deployBaseContract);

      const transferAmount = TOTAL_SUPPLY - 1;
      await expect(contract.transfer(addr1, transferAmount)).not.to.be.reverted;
    });
    it("Should revert when trying to transfer more than available tokens", async function () {
      const { contract, owner, addr1 } = await loadFixture(deployBaseContract);

      const transferAmount = TOTAL_SUPPLY + 1;
      await expect(contract.transfer(addr1, transferAmount)).to.be.revertedWithCustomError(contract, "ERC20InsufficientBalance");
    });
    it("Should be able to burn all the tokens from owner account", async function () {
      const { contract, owner, addr1 } = await loadFixture(deployBaseContract);

      await expect(contract.burnItAll(owner)).not.to.be.reverted;
      expect(await contract.balanceOf(owner)).to.equal(0);
      expect(await contract.totalSupply()).to.equal(0);
    });
  });
});