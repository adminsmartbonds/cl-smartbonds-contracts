import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import fs from "node:fs";

// The below are Sepolia values
const FUNCTIONS_ROUTER_ADDRESS = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
const CCIP_ROUTER_ADDRESS = "0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59";
const LINK_ADDRESS = "0x779877A7B0D9E8603169DdbD7836e478b4624789";
const SUBSCRIPTION_ID = "2664";
const DON_ID = "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
const CALLBACK_GAS_LIMIT = "300000";
const CCIP_GAS_LIMIT = "1000000";
const SECRET_SLOT = "0";
const SECRET_VERSION = "1715862735";

const REQUEST_DEPLOY_CODE_FILE = "functions/src/SBRequestDeployContract.js";

const ContractManagerDeployModule = buildModule("SBContractManagerDeploy_V11", (m) => {
  const functionsRouterAddr = m.getParameter("_functionsRouter", FUNCTIONS_ROUTER_ADDRESS);
  const ccipRouterAddr = m.getParameter("_ccipRouterAddress", CCIP_ROUTER_ADDRESS);
  const linkAddr = m.getParameter("_linkAddress", LINK_ADDRESS);
  const subscriptionId = m.getParameter("_subId", SUBSCRIPTION_ID);
  const donId = m.getParameter("_donId", DON_ID);
  const requestDeployCodeFile = m.getParameter("requestDeployCode", REQUEST_DEPLOY_CODE_FILE);
  const requestDeployCode = fs.readFileSync(requestDeployCodeFile.defaultValue!.toString(), 'utf8');
  const secretSlot = m.getParameter("_secretSlot", SECRET_SLOT);
  const secretVersion = m.getParameter("_secretVersion", SECRET_VERSION);
  const callbackGasLimit = m.getParameter("_callbackGasLimit", CALLBACK_GAS_LIMIT);
  const ccipGasLimit = m.getParameter("_ccipGasLimit", CCIP_GAS_LIMIT);
  const functionsData = [functionsRouterAddr, subscriptionId, donId, requestDeployCode];
  const gasData = [callbackGasLimit, ccipGasLimit];

  const sbContractManager = m.contract("SBContractManager",
      [ccipRouterAddr, linkAddr, functionsData, secretSlot, secretVersion, gasData]);

  return { sbContractManager };
});

export default ContractManagerDeployModule;
