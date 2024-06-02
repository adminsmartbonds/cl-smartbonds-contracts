const fs = require("fs")
const { Location, ReturnType, CodeLanguage } = require("@chainlink/functions-toolkit")

const encodedPayload = fs.readFileSync("functions/simconfig/encoded-payload.txt", "utf8");
const testPayload = "eJyrVkrOzyspSkwuUbKqVkpMylSyUgpxDQ5R0lFKqixJTc5PSQWKGFQYKNXqKBUkFiXmFitZRVcrlVQWgCSKS4oy89KBissSc0pTYXprY2sB7/wcVA==";

// Configure the request by setting the fields below
const requestConfig = {
    // String containing the source code to be executed
    source: fs.readFileSync("functions/src/SBRequestDeployContract.js", 'utf8'),
    //source: fs.readFileSync("./API-request-example.js").toString(),
    // Location of source code (only Inline is currently supported)
    codeLocation: Location.Inline,
    // Optional. Secrets can be accessed within the source code with `secrets.varName` (ie: secrets.apiKey). The secrets object can only contain string values.
    secrets: { apiKey: process.env.GOOGLE_API_KEY ?? "" },
    // Optional if secrets are expected in the sourceLocation of secrets (only Remote or DONHosted is supported)
    secretsLocation: Location.DONHosted,
    // Args (string only array) can be accessed within the source code with `args[index]` (ie: args[0]).
    args: [
        "11155111",
        "0xC63c42e4D539af756b4B2cD67E76a7eC1329eA04",
        "SBTEST001",
        testPayload
    ],
    // Code language (only JavaScript is currently supported)
    codeLanguage: CodeLanguage.JavaScript,
    // Expected type of the returned value
    expectedReturnType: ReturnType.uint256,
}


module.exports = requestConfig
