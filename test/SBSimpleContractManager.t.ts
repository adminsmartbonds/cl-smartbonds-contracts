import { expect } from "chai";
import hre from "hardhat";
import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import fs from "node:fs";
import {zipBase64} from "./helpers/zipencode";


describe("SBSimpleContractManager", function () {
  const DEPLOY_JS_CODE_FILE = "functions/src/SBRequestDeployContract.js";
  const SUBSCRIPTION_ID = "4242";
  const DON_ID = "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
  const CALLBACK_GAS_LIMIT = "50000";
  const SECRET_SLOT = "1";
  const SECRET_VERSION = "123245";
  const CHAIN_ID = "4113"

  const deployCode = fs.readFileSync(DEPLOY_JS_CODE_FILE, 'utf8');

  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContractManagerFixture() {
    // Get a bunch of fake addresses for the purposes of initializing the contract
    const [owner, functionRouterAddr] = await hre.ethers.getSigners();

    const contractManagerFactory = await hre.ethers.getContractFactory("SBSimpleContractManager");
    const contractManager = await contractManagerFactory.deploy(
        functionRouterAddr, SUBSCRIPTION_ID, DON_ID,deployCode, SECRET_SLOT, SECRET_VERSION, CALLBACK_GAS_LIMIT);

    return { contractManager, owner, functionRouterAddr };
  }

  describe("Deployment", function () {
    it("Should Deploy correctly", async function () {
      const { contractManager, owner } = await loadFixture(deployContractManagerFixture);

      expect(contractManager).not.to.be.null;
      expect(owner).not.to.be.null;
      expect(await contractManager.owner()).to.equal(owner.address);
    });
  });

  const CONTRACT_FILE = "test/data/SBBaseContract.json"
  const PARAMS_FILE = "test/data/SBBaseContract.params.json"
  const CONTRACT_ID = "SBDUM001"

  describe("Functions", function () {
    describe("DeployContract", function () {
      it("This should fail but return with 0 and an emit failure", async function () {
        const { contractManager } = await loadFixture(deployContractManagerFixture);

        await expect(contractManager.deployContract(CHAIN_ID, CONTRACT_ID)).to.be.reverted;
      });
    });
    describe("GetInfo", function () {
      it("Should get info I initialized with", async function () {
        const { contractManager, functionRouterAddr } = await loadFixture(deployContractManagerFixture);
        const info = await contractManager.getInfo();

        expect(info.secretVersion).to.equal(SECRET_VERSION);
        expect(info.secretSlot).to.equal(SECRET_SLOT);
        expect(info.donId).to.equal(DON_ID);
        expect(info.subId).to.equal(SUBSCRIPTION_ID);
        expect(info.functionsRouter).to.equal(functionRouterAddr);
        expect(info.callbackGasLimit).to.equal(CALLBACK_GAS_LIMIT);
      });
      it("Should get the same source code", async function () {
        const { contractManager } = await loadFixture(deployContractManagerFixture);

        expect(await contractManager.getFunctionsSourceCode()).to.equal(deployCode);
      });
      it("Should be able to change the gas limit", async function () {
        const { contractManager } = await loadFixture(deployContractManagerFixture);
        const NEW_GAS_VALUE = 1000;

        await expect(contractManager.setCallbackGasLimit(NEW_GAS_VALUE)).not.to.be.reverted;
        const info = await contractManager.getInfo();

        expect(info.callbackGasLimit).to.equal(NEW_GAS_VALUE);
      });
    });
  });

  describe("Events", function () {
  });
});
