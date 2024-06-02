import {SecretsManager} from "@chainlink/functions-toolkit";
import {ethers} from "@chainlink/contracts/node_modules/ethers";

const checkSecrets = async (network: string) => {
    // hardcoded for Sepolia
    const gatewayUrls = [
        "https://01.functions-gateway.testnet.chain.link/",
        "https://02.functions-gateway.testnet.chain.link/",
    ]

    let routerAddress = "";
    let privateKey = "";
    let donId = "";
    let rpcUrl = "";

    switch(network) {
        case "sepolia":
            routerAddress = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
            privateKey = process.env.SEPOLIA_PRIVATE_KEY || "";
            donId = "fun-ethereum-sepolia-1";
            rpcUrl = process.env.INFURA_SEPOLIA_RPC_URL || "";
            break;
        case "fuji":
            routerAddress = "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0";
            privateKey = process.env.FUJI_PRIVATE_KEY || "";
            donId = "fun-avalanche-fuji-1";
            rpcUrl = process.env.INFURA_FUJI_RPC_URL || "";
            break;
        default:
            break;
    }

    // Initialize ethers signer and provider to interact with the contracts onchain
    if (!privateKey || privateKey === "" || routerAddress === "") {
        throw new Error("Private key not provided or network unknown use 'fuji' or 'sepolia'");
    }
    const rpcAPIKey = process.env.INFURA_API_KEY;
    const apiKey = process.env.GOOGLE_API_KEY;

    if (!rpcUrl) {
        throw new Error(`INFURA RPC URL not provided  - check your environment variables`)
    }
    if (!rpcAPIKey) {
        throw new Error(`INFURA RPC API Key not provided  - check your environment variables`)
    }
    if (!apiKey) {
        throw new Error(`GOOGLE Secrets API Key not provided  - check your environment variables`)
    }

    const provider = new ethers.providers.JsonRpcProvider(rpcUrl + rpcAPIKey)
    const wallet = new ethers.Wallet(privateKey)
    const signer = wallet.connect(provider) // create ethers signer for signing transactions

    // First encrypt secrets and upload the encrypted secrets to the DON
    const secretsManager = new SecretsManager({
        signer: signer,
        functionsRouterAddress: routerAddress,
        donId: donId,
    })
    await secretsManager.initialize()

    // Encrypt secrets and upload to DON
    const secretsList = await secretsManager.listDONHostedEncryptedSecrets(gatewayUrls);

    if (!secretsList)
        throw new Error(`Could not retrieve the list of secrets`)


    console.log("✅ Secrets retrieved OK");
    for (let response of secretsList.result.nodeResponses) {
        if (response.rows) {
            for (let secretsInfo of response.rows) {
                const expirationDate = new Date(secretsInfo.expiration);

                console.log(`Secret slot id: ${secretsInfo.slot_id}, version: ${secretsInfo.version}, expiration: ${expirationDate.toLocaleString()}`)
            }
        }
    }
}

/**
 *  Execution entry point
 **/
checkSecrets(process.argv.slice(2)[0]).catch((err) => {
    console.error("Secrets Retrieval failed: ", err)
    process.exit(1)
});
