import hre from "hardhat";
import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {expect} from "chai";

describe("SBDefiContract", function () {
    const INITIAL_SUPPLY = 10000;
    const VANILLA_PROPS = [
        /* canBurn */ false, /* canMint */ false, /* hasMaxTotalSupply */ false, /* hasTaxFee */ false,
        /* hasBurnFee */ false, /* hasRewardFee */ false, /* changeOwner */ false, /* hasDocument */ false, /* hasTokenLimit */ false ];
    const VANILLA_PARAMS = [
        /* initialSupply */ INITIAL_SUPPLY, /* decimals */ 0, /* maxTotalSupply */ 0,
        /* taxRecipient */ "0x0000000000000000000000000000000000000000", /* taxFeeBPS */ 0, /* burnFeeBPS */ 0, /* rewardsFeeBPS */ 0,
        /* tokenOwner */ "0x0000000000000000000000000000000000000000", /* document */ "", /* tokenLimit */ 0 ];

    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployBaseContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, addr1, addr2] = await hre.ethers.getSigners(); // Get the number of fake addresses you need

        const defiContract = await hre.ethers.getContractFactory("SBDefiContract");
        const contract = await defiContract.deploy("SBDefiContract001", "SBDEF001", VANILLA_PROPS, VANILLA_PARAMS);

        console.log("RETURN");
        return {contract, owner, addr1, addr2};
    }

    describe("Deployment", function () {
        it("Should deploy", async function () {
            const {contract, owner} = await loadFixture(deployBaseContract);

            expect(contract).not.to.be.null;
            expect(owner).not.to.be.null;
        });
    });

    // TODO this needs a lot more tests!
})
