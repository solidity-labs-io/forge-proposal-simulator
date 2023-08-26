// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";
import {Script} from "@forge-std/Script.sol";

import {Addresses} from "@addresses/Addresses.sol";

/*
How to use:
forge script test/proposals/StandardProposal.s.sol:StandardProposal \
    -vvvv \
    --rpc-url $ETH_RPC_URL \
    --broadcast
Remove --broadcast if you want to try locally first, without paying any gas.
*/

/// ----------------- required environment variables -----------------

/// DEPLOYER_KEY must be set to the private key of the deployer,
/// otherwise the script will fail with a non descriptive error message.

/// ADDRESSES_PATH must be set to the correct json path for the addresses,
/// otherwise the script will fail with a non descriptive error message.

/// if a strange error message appears, ensure the correct environment
/// variables are set for the run you are doing.

abstract contract StandardProposal is Script {
    uint256 private PRIVATE_KEY;
    Addresses private addresses;

    bool private DEBUG;
    bool private DO_DEPLOY;
    bool private DO_AFTER_DEPLOY;
    bool private DO_AFTER_DEPLOY_SETUP;
    bool private DO_BUILD;
    bool private DO_RUN;
    bool private DO_TEARDOWN;
    bool private DO_VALIDATE;
    bool private DO_PRINT;

    /// default to automatically setting all environment variables to true
    constructor() {
        PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYER_KEY"));
        DEBUG = vm.envOr("DEBUG", true);
        DO_DEPLOY = vm.envOr("DO_DEPLOY", true);
        DO_AFTER_DEPLOY = vm.envOr("DO_AFTER_DEPLOY", true);
        DO_AFTER_DEPLOY_SETUP = vm.envOr("DO_AFTER_DEPLOY_SETUP", true);
        DO_BUILD = vm.envOr("DO_BUILD", true);
        DO_RUN = vm.envOr("DO_RUN", true);
        DO_TEARDOWN = vm.envOr("DO_TEARDOWN", true);
        DO_VALIDATE = vm.envOr("DO_VALIDATE", true);
        DO_PRINT = vm.envOr("DO_PRINT", true);

        addresses = new Addresses();
    }

    function run() public {
        address deployerAddress = vm.addr(PRIVATE_KEY);

        console.log("deployerAddress: ", deployerAddress);

        vm.startBroadcast(PRIVATE_KEY);
        if (DO_DEPLOY) deploy(addresses, deployerAddress);
        if (DO_AFTER_DEPLOY) afterDeploy(addresses, deployerAddress);
        if (DO_AFTER_DEPLOY_SETUP) afterDeploySetup(addresses);
        vm.stopBroadcast();

        if (DO_BUILD) build(addresses);
        if (DO_RUN) run(addresses, deployerAddress);
        if (DO_TEARDOWN) teardown(addresses, deployerAddress);
        if (DO_VALIDATE) validate(addresses, deployerAddress);
        if (DO_PRINT) {
            printCalldata(addresses);
            printProposalActionSteps();
        }

        if (DO_DEPLOY) {
            (
                string[] memory recordedNames,
                address[] memory recordedAddresses
            ) = addresses.getRecordedAddresses();
            for (uint256 i = 0; i < recordedNames.length; i++) {
                console.log("Deployed", recordedAddresses[i], recordedNames[i]);
            }

            console.log();

            for (uint256 i = 0; i < recordedNames.length; i++) {
                console.log('_addAddress("%s",', recordedNames[i]);
                console.log(block.chainid);
                console.log(", ");
                console.log(recordedAddresses[i]);
                console.log(");");
            }
        }
    }

    /// -------- standard interface for a proposal --------

    function deploy(Addresses, address) public virtual;

    function afterDeploy(Addresses, address) public virtual;

    function afterDeploySetup(Addresses) public virtual;

    function build(Addresses) public virtual;

    function run(Addresses, address) public virtual;

    function printCalldata(Addresses addresses) public virtual;

    function teardown(Addresses, address) public virtual;

    function validate(Addresses, address) public virtual;

    function printProposalActionSteps() public virtual;
}
