pragma solidity 0.8.19;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";
import {MULTISIG_01} from "@examples/multisig/MULTISIG_01.sol";
import {Constants} from "@utils/Constants.sol";

// @notice MultisigScript is a script that run MULTISIG_01 proposal
// MULTISIG_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the multisig address
// Finally the proposal whitelist the ERC20 token in the Vault contract
// @dev Use this script to simulates or run a single proposal
// Use this as a template to create your own script
// `forge script script/Multisig.s.sol:MultisigScript -vvvv --rpc-url {rpc} --broadcast --verify --etherscan-api-key {key}`
contract MultisigScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor() ScriptSuite(ADDRESSES_PATH, new MULTISIG_01()) {}

    function run() public override {
        // Verify if the multisig address is a contract; if it is not
        // (e.g. running on a empty blockchain node), set the multisig
        // code to Safe Multisig code
        address multisig = addresses.getAddress("DEV_MULTISIG");

        uint256 multisigSize;
        assembly {
            multisigSize := extcodesize(multisig)
        }
        if (multisigSize == 0) {
            vm.etch(multisig, Constants.SAFE_BYTECODE);
        }

        proposal.setDebug(true);

        // Execute proposal
        super.run();
    }
}
