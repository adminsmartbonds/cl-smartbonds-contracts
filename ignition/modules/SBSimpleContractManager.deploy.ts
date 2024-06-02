import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import fs from "node:fs";

// These defaults are for Sepolia but we try to feed everything through config
const FUNCTIONS_ROUTER_ADDRESS = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
const SUBSCRIPTION_ID = "2664";
const DON_ID = "0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000";
const SECRET_SLOT = "0";
const SECRET_VERSION = "1715862735";
const CALLBACK_GAS_LIMIT = 50000;

// The code file we will currently keep as the same
const REQUEST_DEPLOY_CODE_FILE = "functions/src/SBRequestDeployContract.js";

const SimpleContractManagerDeployModule = buildModule("SBSimpleContractManagerDeploy_V22", (m) => {
  const functionsRouterAddr = m.getParameter("_functionsRouter", FUNCTIONS_ROUTER_ADDRESS);
  const subscriptionId = m.getParameter("_subId", SUBSCRIPTION_ID);
  const donId = m.getParameter("_donId", DON_ID);
  const requestDeployCodeFile = m.getParameter("requestDeployCode", REQUEST_DEPLOY_CODE_FILE);
  const requestDeployCode = fs.readFileSync(requestDeployCodeFile.defaultValue!.toString(), 'utf8');
  const secretSlot = m.getParameter("_secretSlot", SECRET_SLOT);
  const secretVersion = m.getParameter("_secretVersion", SECRET_VERSION);
  const callbackGasLimit = m.getParameter("_callbackGasLimit", CALLBACK_GAS_LIMIT);

  const simpleContractManager = m.contract("SBSimpleContractManager",
      [functionsRouterAddr, subscriptionId, donId, requestDeployCode, secretSlot, secretVersion, callbackGasLimit]);

  return { simpleContractManager };
});

export default SimpleContractManagerDeployModule;
