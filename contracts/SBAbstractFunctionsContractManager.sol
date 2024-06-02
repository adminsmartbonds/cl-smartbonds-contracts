// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

abstract contract SBAbstractFunctionsContractManager is FunctionsClient, Pausable, OwnerIsCreator {

    string internal              requestDeployContractCode;
    uint64 internal              subId;
    bytes32 internal             donId;
    uint64 internal              secretVersion;
    uint8 internal               secretSlot;
    uint32 internal              callbackGasLimit;

    constructor(
        address _functionsRouter,
        uint64 _subId,
        bytes32 _donId,
        string memory _requestDeployContractCode,
        uint8 _secretSlot,
        uint64 _secretVersion,
        uint32 _callbackGasLimit
    ) FunctionsClient(_functionsRouter) {
        requestDeployContractCode = _requestDeployContractCode;
        subId = _subId;
        donId = _donId;
        secretVersion = _secretVersion;
        secretSlot = _secretSlot;
        callbackGasLimit = _callbackGasLimit;
    }

    /* ------------------------- Pause and Unpause implementation -------------------- */

    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    /* ------------ The following functions allow changing internal values ----------- */

    function setSecretVersion(uint64 _secretVersion) external whenNotPaused onlyOwner {
        secretVersion = _secretVersion;
    }

    function setSecretSlot(uint8 _secretSlot) external whenNotPaused onlyOwner {
        secretSlot = _secretSlot;
    }

    function setCallbackGasLimit(uint32 _callbackGasLimit) external whenNotPaused onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    function getFunctionsSourceCode() public view onlyOwner returns(string memory) {
        return string(requestDeployContractCode);
    }

    /* --------- The following functions help deploy a contract to the chain --------- */

    error UnknownFunctionCode(uint64 functionCode);
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);

    enum DeploymentLifecycle { requested, scheduled, deployed, errored }

    struct ContractInfo {
        bytes32 requestId;
        DeploymentLifecycle status;
        uint256 lastRequestedTimestamp;
        uint256 lastScheduledTimestamp;
        uint256 lastResultTimestamp;
        bytes32 txHash;
    }

    mapping (string => ContractInfo) contractInfoMap;
    string[] private contractIdArray;

    function getContractInfo(string memory _contractId) public view onlyOwner returns(ContractInfo memory) {
        return contractInfoMap[_contractId];
    }

    function getAllContractIds() public view returns(string[] memory){
        return contractIdArray;
    }

    /*
     * @notice Retrieves the contract IDs in a specific status - WARNING this can be gas expensive
     * @param status the status to filter on (0 = prepared, 1 = requested, 2 = deployed, 3 = errored)
     */
    function getContractIds(DeploymentLifecycle status) public view returns(string[] memory result){
        string[] memory interimResult = new string[](contractIdArray.length);
        uint            count = 0;

        for (uint i = 0; i < contractIdArray.length; i++) {
            string memory       id = contractIdArray[i];
            if (contractInfoMap[id].status == status) {
                interimResult[count] = id;
                count++;
            }
        }
        result = new string[](count);
        for (uint i = 0; i < count; i++) {
            result[i] = interimResult[i];
        }
    }

    function deployContract(uint256 _chainId, string memory _contractId) external virtual;

    /* ------------------ The following is Functions code ------------------------ */
    using Strings for uint256;
    using Strings for uint32;
    using Strings for address;

    mapping(bytes32 => string) private contractTxMap;

    event RequestFulfilled(bytes32 indexed requestId, bool error, bytes responseOrError);
    event ContractDeployed(string contractId, bytes32 txHash);

    using FunctionsRequest for FunctionsRequest.Request;

    /*
     * Send a Chainlink Functions request to request the deployment of a contract
     *
     * @param _contractId The identifier of the contract payload for the manager
     */
    function _sendDeployRequest(string memory _contractId) internal returns (bytes32 requestId) {
        // Internal Effects
        FunctionsRequest.Request memory req;
        string[] memory args = new string[](3);

        req.initializeRequestForInlineJavaScript(requestDeployContractCode); // Initialize the request with JS code
        req.addDONHostedSecrets(secretSlot, secretVersion);
        args[0] = block.chainid.toString();
        args[1] = _contractId;
        args[2] = address(this).toHexString();
        req.setArgs(args);

        bytes memory data = req.encodeCBOR();

        requestId = _sendRequest(data, subId, callbackGasLimit, donId);
        contractTxMap[requestId] = _contractId;

        ContractInfo memory info = contractInfoMap[_contractId];
        info.status = DeploymentLifecycle.requested;
        info.lastRequestedTimestamp = block.timestamp;
        info.requestId = requestId;
        contractInfoMap[_contractId] = info;
        contractIdArray.push(_contractId);
    }

    /**
     * @notice Callback function for fulfilling the Chainlink Functions request
     *
     * @param requestId The ID of the request that was either fillfilled or errored out
     * @param err If an error occured in the Chainlink Functions call this will hold that error.
     */
    function _fulfillRequest(bytes32 requestId, bytes memory /* response */, bytes memory err) internal override whenNotPaused {
        // We are currently only handling deployment requests, so no need to have a big selector set here.
        bool                isError;
        bytes memory        error;
        string memory       contractId = contractTxMap[requestId];
        ContractInfo memory contractInfo = contractInfoMap[contractId];

        if (err.length > 0) {
            isError = true;
            error = err;
            contractInfo.status = DeploymentLifecycle.errored;
            contractInfo.lastResultTimestamp = block.timestamp;
        } else {
            isError = false;
            contractInfo.status = DeploymentLifecycle.scheduled;
            contractInfo.lastScheduledTimestamp = block.timestamp;
        }
        contractInfoMap[contractId] = contractInfo;

        emit RequestFulfilled(requestId, isError, error);
    }

    function notifyDeploymentFullfilled(string memory _contractId, bytes32 _txHash) external onlyOwner {
        ContractInfo memory contractInfo = contractInfoMap[_contractId];

        contractInfo.status = DeploymentLifecycle.deployed;
        contractInfo.lastResultTimestamp = block.timestamp;
        contractInfo.txHash = _txHash;
        contractInfoMap[_contractId] = contractInfo;

        emit ContractDeployed(_contractId, _txHash);
    }
}
