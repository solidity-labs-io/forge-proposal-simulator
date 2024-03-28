pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {BRAVO_01} from "@examples/governor-bravo/BRAVO_01.sol";
import {Constants} from "@utils/Constants.sol";
import {IProposal} from "@proposals/IProposal.sol";

// @notice GovernorBravoScript is a script that runs BRAVO_01 proposal.
// BRAVO_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the timelock address
// Finally the proposal whitelist the ERC20 token in the Vault contract
// @dev Use this script to simulates or run a single proposal
// Use this as a template to create your own script
// `forge script script/GovernorBravo.s.sol:GovernorBravoScript -vvvv --rpc-url ${rpc} --broadcast --verify --etherscan-api-key ${key}`
contract GovernorBravoScript is Script {
    IProposal proposal;

    constructor() {
        proposal = new BRAVO_01();
    }

    function run() public {
        // Execute proposal
        proposal.setDebug(true);
        proposal.run();
    }
}
