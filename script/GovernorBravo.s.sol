pragma solidity ^0.8.0;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";
import {BRAVO_01} from "@examples/governor-bravo/BRAVO_01.sol";
import {Constants} from "@utils/Constants.sol";

// @notice GovernorBravoScript is a script that runs BRAVO_01 proposal.
// BRAVO_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the timelock address
// Finally the proposal whitelist the ERC20 token in the Vault contract
// @dev Use this script to simulates or run a single proposal
// Use this as a template to create your own script
// `forge script script/GovernorBravo.s.sol:GovernorBravoScript -vvvv --rpc-url ${rpc} --broadcast --verify --etherscan-api-key ${key}`
contract GovernorBravoScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor()
        ScriptSuite(ADDRESSES_PATH, new BRAVO_01(), vm.envUint("PRIVATE_KEY"))
    {}

    function run() public override {
        // Execute proposal
        proposal.setDebug(true);
        super.run();
    }
}
