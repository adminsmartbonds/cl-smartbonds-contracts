// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {SBAbstractFunctionsContractManager} from "./SBAbstractFunctionsContractManager.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract SBContractManager is SBAbstractFunctionsContractManager, CCIPReceiver  {

    IRouterClient private       ccipRouter;
    LinkTokenInterface private  linkToken;
    uint32 public               ccipGasLimit;

    struct FunctionsData {
        address functionsRouter;
        uint64  subId;
        bytes32 donId;
        string  requestDeployContractCode;
    }

    struct GasData {
        uint32 callbackGasLimit;
        uint32 ccipGasLimit;
    }

    constructor(
        address _ccipRouter,
        address _link,
        FunctionsData memory _functionsData,
        uint8 _secretSlot,
        uint64 _secretVersion,
        GasData memory _gasData
    ) SBAbstractFunctionsContractManager(
        _functionsData.functionsRouter,
        _functionsData.subId,
        _functionsData.donId,
        _functionsData.requestDeployContractCode,
        _secretSlot,
        _secretVersion,
        _gasData.callbackGasLimit
    ) CCIPReceiver(_ccipRouter)
    {
        ccipRouter = IRouterClient(_ccipRouter);
        linkToken = LinkTokenInterface(_link);
        ccipGasLimit = _gasData.ccipGasLimit;
    }

    struct ContractManagerInfo {
        uint64 subId;
        bytes32 donId;
        uint64 secretVersion;
        uint8 secretSlot;
        address functionsRouter;
        address ccipRouter;
        address linkToken;
        uint32 callbackGasLimit;
        uint32 ccipGasLimit;
    }

    function getInfo() public view onlyOwner returns(ContractManagerInfo memory) {
        return ContractManagerInfo(
            subId, donId,
            secretVersion, secretSlot,
            address(i_functionsRouter),
            address(ccipRouter),
            address(linkToken),
            callbackGasLimit,
            ccipGasLimit
        );
    }

    function setCCIPGasLimit(uint32 _ccipGasLimit) external onlyOwner {
        ccipGasLimit = _ccipGasLimit;
    }

    /* ------ The following functions help manage connectivity to other chains ------- */

    struct ChainlinkInfo {
        address receiverAddress;
        uint64 selector;
    }

    mapping(uint256 => ChainlinkInfo) private chainlinkInfoMap;
    uint256[] private chainIdArray;

    function addKnownChain(uint256 _chainId, address _receiverAddress, uint64 _chainlinkSelector) public whenNotPaused onlyOwner {
        ChainlinkInfo memory chainlinkInfo = chainlinkInfoMap[_chainId];
        require(chainlinkInfo.receiverAddress == ZERO_ADDRESS, "There is already a defined entry for this chainId use update function");

        chainlinkInfo.receiverAddress = _receiverAddress;
        chainlinkInfo.selector = _chainlinkSelector;
        chainlinkInfoMap[_chainId] = chainlinkInfo;
        chainIdArray.push(_chainId);
    }

    function updateKnownChain(uint256 _chainId, address _receiverAddress, uint64 _chainlinkSelector) public whenNotPaused onlyOwner {
        ChainlinkInfo memory chainlinkInfo = chainlinkInfoMap[_chainId];

        chainlinkInfo.receiverAddress = _receiverAddress;
        chainlinkInfo.selector = _chainlinkSelector;
        chainlinkInfoMap[_chainId] = chainlinkInfo;
    }

    function getChainInfo(uint256 chainId) public view onlyOwner returns(ChainlinkInfo memory) {
        return chainlinkInfoMap[chainId];
    }

    function getKnownChains() public view onlyOwner returns(uint256[] memory) {
        return chainIdArray;
    }

    /* --------- The following functions help deploy a contract to the chain --------- */

    mapping(string => bytes32) private ccipSendMap;
    string[] private ccipSendArray;

    function deployContract(uint256 _chainId, string memory _contractId) external override whenNotPaused {
        ContractInfo memory contractInfo = getContractInfo(_contractId);
        require(contractInfo.status != DeploymentLifecycle.deployed, "This contract has already been deployed");

        if (_chainId == block.chainid) {
            _sendDeployRequest(_contractId);
        } else {
            bytes memory payLoad = abi.encode(_chainId, _contractId);
            bytes memory data = abi.encode(uint64(SBFunction.Deploy), payLoad);

            ccipSendMap[_contractId] = sendMessageAcross(_chainId, SBFunction.Deploy, data);
        }
    }

    function getCCIPSentList() public view returns(string[] memory) {
        return ccipSendArray;
    }

    function getCCIPSendId(string memory _contractId) public view returns(bytes32) {
        return ccipSendMap[_contractId];
    }

    /* ------------------ The following is CCIPReceiver code ------------------------ */

    enum SBFunction {
        Deploy
    }

    /*
     * Utility function to help  convert enums to strings for the SBFunction enums.
     *
     * @param _function - The SBFunction enum expressed as a UINT64
     */
    function functionEnumToString(uint64 _function) internal pure returns(string memory) {
        string[1] memory functionStrings = ["Deploy"];

        return functionStrings[_function];
    }

    error UnknownChain(uint256 chainId);

    address private constant ZERO_ADDRESS = address(0x0);

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        string functionCall, // The text being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    function sendMessageAcross(uint256 _chainId, SBFunction _functionIdentifier, bytes memory _data) internal returns (bytes32 messageId) {
        // If we're not on the right chain then forward the request on to the right chain.
        ChainlinkInfo memory chainlinkInfo = chainlinkInfoMap[_chainId];

        if (chainlinkInfo.receiverAddress == ZERO_ADDRESS) {
            revert UnknownChain(_chainId);
        }
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(chainlinkInfo.receiverAddress), // ABI-encoded receiver address
            data: _data, // ABI-encoded string
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array indicating no tokens are being sent
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: ccipGasLimit})
            ),
            // Set the feeToken  address, indicating LINK will be used for fees
            feeToken: address(linkToken)
        });

        // Get the fee required to send the message
        uint256 fees = ccipRouter.getFee(
            chainlinkInfo.selector,
            evm2AnyMessage
        );

        if (fees > linkToken.balanceOf(address(this))) {
            revert NotEnoughBalance(linkToken.balanceOf(address(this)), fees);
        }

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        linkToken.approve(i_ccipRouter, fees);

        // Send the message through the router and store the returned message ID
        messageId = ccipRouter.ccipSend(chainlinkInfo.selector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            chainlinkInfo.selector,
            chainlinkInfo.receiverAddress,
            functionEnumToString(uint64(_functionIdentifier)),
            address(linkToken),
            fees
        );
        return messageId;
    }

    // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        string fctName // The text that was received.
    );

    /// handle a received message
    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override whenNotPaused {
        (uint64 fct, bytes memory payLoad) = abi.decode(any2EvmMessage.data, (uint64, bytes));
        string memory fctName = functionEnumToString(fct);

        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector, // fetch the source chain identifier (aka selector)
            abi.decode(any2EvmMessage.sender, (address)), // abi-decoding of the sender address,
            fctName
        );

        handleMessage(SBFunction(fct), payLoad);
    }

    function handleMessage(SBFunction _fct, bytes memory payload) internal {
        if (SBFunction.Deploy == _fct) {
            // We received a deploy request, now unpack the payload accordingly
            (uint256 chainId, string memory contractId) = abi.decode(payload, (uint256, string));

            require(chainId == block.chainid, "Received a remote request but wasn't for this chain");

            _sendDeployRequest(contractId);
        } else {
            revert UnknownFunctionCode(uint64(_fct));
        }
    }
}
