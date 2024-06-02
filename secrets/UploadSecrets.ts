import {SecretsManager} from "@chainlink/functions-toolkit";
import {ethers} from "@chainlink/contracts/node_modules/ethers";

// TODO might be nicer to do this via a Web interface integrated with MetaMask wallet.

const uploadSecrets = async (network: string) => {
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

    const secrets = { apiKey: apiKey }
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
    const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets)
    const slotIdNumber = 0 // slot ID where to upload the secrets
    const expirationTimeMinutes = 1440 // expiration time in minutes of the secrets, 1 month


    console.log(
        `Upload encrypted secret to gateways ${gatewayUrls}. slotId ${slotIdNumber}. Expiration in minutes: ${expirationTimeMinutes}`
    )
    // Upload secrets
    const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
        encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
        gatewayUrls: gatewayUrls,
        slotId: slotIdNumber,
        minutesUntilExpiration: expirationTimeMinutes,
    })

    if (!uploadResult.success)
        throw new Error(`Encrypted secrets not uploaded to ${gatewayUrls}`)

    console.log(
        `\n✅ Secrets uploaded properly to gateways ${gatewayUrls}! Gateways response: `,
        uploadResult
    )

    const donHostedSecretsVersion = uploadResult.version // fetch the reference of the encrypted secrets
    console.log(`\n✅ Secrets version: ${donHostedSecretsVersion}`)
}

/**
 *  Execution entry point
 **/
uploadSecrets(process.argv.slice(2)[0]).catch((err) => {
    console.error("Secrets upload failed: ", err)
    process.exit(1)
});
