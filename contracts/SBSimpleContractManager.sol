// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {SBAbstractFunctionsContractManager} from "./SBAbstractFunctionsContractManager.sol";


contract SBSimpleContractManager is SBAbstractFunctionsContractManager {
    constructor(
        address _functionsRouter,
        uint64 _subId,
        bytes32 _donId,
        string memory _requestDeployContractCode,
        uint8 _secretSlot,
        uint64 _secretVersion,
        uint32 _callbackGasLimit
    ) SBAbstractFunctionsContractManager(
        _functionsRouter,
        _subId,
        _donId,
        _requestDeployContractCode,
        _secretSlot,
        _secretVersion,
        _callbackGasLimit)
    {
    }

    struct ContractManagerInfo {
        uint64 subId;
        bytes32 donId;
        uint64 secretVersion;
        uint8 secretSlot;
        address functionsRouter;
        uint32 callbackGasLimit;
    }

    function getInfo() public view onlyOwner returns(ContractManagerInfo memory) {
        return ContractManagerInfo(subId, donId, secretVersion, secretSlot, address(i_functionsRouter), callbackGasLimit);
    }

    function deployContract(uint256 _chainId, string memory _contractId) external override whenNotPaused  {
        ContractInfo memory contractInfo = getContractInfo(_contractId);
        require(contractInfo.status != DeploymentLifecycle.deployed, "This contract has already been deployed");
        require(_chainId == block.chainid, "This contract only supports deploymernt on its own blockchain");

        _sendDeployRequest(_contractId);
    }
}
