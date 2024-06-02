import fs from "node:fs";
import {deflate} from "pako";

export function zip(contractFile: string, paramsFile: string) {
    // We map the contents of the file to make sure the content is correct
    // then we stringify it to make the JSON as compact as possible.
    // then we zip it and base64 encode the zip output.
    const contractData = fs.readFileSync(contractFile, 'utf8');
    const jsonContract = JSON.parse(contractData) as ContractJson;
    const paramData = fs.readFileSync(paramsFile, 'utf8');
    const jsonParams = JSON.parse(paramData) as ParamsJson[];

    const dataToZip: ContractAndParams = {
        contract: jsonContract,
        params: jsonParams
    };

    const buffer = Buffer.from(JSON.stringify(dataToZip));
    return Buffer.from(deflate(buffer));
}

export function zipBase64(contractFile: string, paramsFile: string) {
    const compressedData = zip(contractFile, paramsFile);

    return  compressedData.toString('base64');
}
