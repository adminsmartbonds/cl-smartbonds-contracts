/* global secrets, args */

async function prepareContract(args) {
    checkKeys()
    const contractId = args[0];
    const contractData = args[1];

    if (!contractId || !contractData) {
        throw new Error("Missing required arguments");
    }
    const requestData = {
        contractId: contractId,
        contractData: contractData
    }
    await Functions.makeHttpRequest({
        method: 'POST',
        url: "https://smartbonds-contract-api-gw-9cabu623.ue.gateway.dev/contract/prepareContract",
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
return await prepareContract(args);
