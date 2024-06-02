import { expect } from "chai";
import hre from "hardhat";
import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import fs from "node:fs";
import {zipBase64} from "./helpers/zipencode";
import {bigint} from "hardhat/internal/core/params/argumentTypes";


describe("SBContractManager", function () {
  const DEPLOY_JS_CODE_FILE = "functions/src/SBRequestDeployContract.js";
  const SUBSCRIPTION_ID = "4242";
  const DON_ID = "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
  const CALLBACK_GAS_LIMIT = "50000";
  const CCIP_GAS_LIMIT = "1000000";
  const CHAIN_ID = "1337";
  const SECRET_SLOT = "1";
  const SECRET_VERSION = "123245";

  const deployCode = fs.readFileSync(DEPLOY_JS_CODE_FILE, 'utf8');


  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContractManagerFixture() {
    // Get a bunch of fake addresses for the purposes of initializing the contract
    const [owner, functionRouterAddr, ccipRouterAddr, linkAddr] = await hre.ethers.getSigners();
    const functionsData = [
      /* functionsRouter */ functionRouterAddr,
      /* subId */ SUBSCRIPTION_ID,
      /* donId */ DON_ID,
      /* requestDeployContractCode */ deployCode
    ]
    const gasData = [
      /* callbackGasLimit */ CALLBACK_GAS_LIMIT,
      /* ccipGasLimit */ CCIP_GAS_LIMIT
    ]

    const contractManagerFactory = await hre.ethers.getContractFactory("SBContractManager");
    const contractManager = await contractManagerFactory.deploy(
        ccipRouterAddr, linkAddr, functionsData, SECRET_SLOT, SECRET_VERSION, gasData);

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
        expect(info.ccipGasLimit).to.equal(CCIP_GAS_LIMIT);
      });
      it("Should get the same source code", async function () {
        const { contractManager } = await loadFixture(deployContractManagerFixture);

        expect(await contractManager.getFunctionsSourceCode()).to.equal(deployCode);
      });
      it("Should be able to change the gas limits", async function () {
        const { contractManager } = await loadFixture(deployContractManagerFixture);
        const NEW_GAS_VALUE1 = 1000n;
        const NEW_GAS_VALUE2 = 2000n;

        await expect(contractManager.setCallbackGasLimit(NEW_GAS_VALUE1)).not.to.be.reverted;
        await expect(contractManager.setCCIPGasLimit(NEW_GAS_VALUE2)).not.to.be.reverted;
        const info = await contractManager.getInfo();

        expect(info.callbackGasLimit).to.equal(NEW_GAS_VALUE1);
        expect(info.ccipGasLimit).to.equal(NEW_GAS_VALUE2);
      });
    });
  });

  describe("Events", function () {
  });
});
