
interface ContractJson {
    bytecode: string;
    abi: string;
}

interface ParamsJson {
    type: string;
    value: string;
}

type ContractParam =  string | bigint;

interface ContractAndParams {
    contract: ContractJson;
    params: ParamsJson[];
}

