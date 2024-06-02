/* global secrets, args */

async function requestContractDeploy(args) {
    checkKeys()
    const chainId = args[0];
    const contractId = args[1];
    const contractMgrAddress = args[2];

    if (!chainId || !contractId) {
        throw new Error("Missing required arguments");
    }
    const requestData = {
        chainId: chainId,
        contractId: contractId,
        contractMgrAddr: contractMgrAddress
    }
    await Functions.makeHttpRequest({
        method: 'POST',
        url: "https://smartbonds-contract-api-gw-9cabu623.ue.gateway.dev/contract/requestDeployContract",
        headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "x-api-key": secrets.apiKey
        },
        data: requestData
    });
    return Functions.encodeUint256(1);
}

// Validate that we have what we need to execute.
function checkKeys() {
    if (!secrets || secrets.apiKey === "") {
        throw Error("No API key provided in secrets");
    }
}

// noinspection JSAnnotator
return await requestContractDeploy(args);
