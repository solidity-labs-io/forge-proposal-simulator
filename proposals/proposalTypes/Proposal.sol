pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";
import {Test} from "@forge-std/Test.sol";
import {IProposal} from "@proposals/proposalTypes/IProposal.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@addresses/Addresses.sol";

abstract contract Proposal is Test, Script, IProposal {
    struct Action {
        address target;
        uint256 value;
        bytes arguments;
        string description;
    }

    Action[] public actions;

    bool internal DEBUG;
    uint256 private PRIVATE_KEY;
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
    }

    function run(Addresses addresses) public {
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
    }

    /// @notice set the debug flag
    function setDebug(bool debug) public {
        DEBUG = debug;
    }

    /// @notice push an action to the proposal
    function _pushAction(uint256 value, address target, bytes memory data, string memory description) internal {
        actions.push(Action({value: value, target: target, arguments: data, description: description}));
    }

    /// @notice push an action to the proposal with a value of 0
    function _pushAction(address target, bytes memory data, string memory description) internal {
        _pushAction(0, target, data, description);
    }

    function _pushAction(uint256 value, address target, bytes memory data) internal {
        _pushAction(value, target, data, "");
    }

    function _pushAction(address target, bytes memory data) internal {
        _pushAction(0, target, data, "");
    }

    function name() external view virtual returns (string memory) {}

    function deploy(Addresses, address) public virtual {}

    function afterDeploy(Addresses, address) public virtual {}

    function afterDeploySetup(Addresses) public virtual {}

    function build(Addresses) public virtual {}

    function run(Addresses, address) public virtual {
	revert("You must override the run function");
    }

    function teardown(Addresses, address) public virtual {}

    function validate(Addresses, address) public virtual {}

    function printProposalActionSteps() public virtual {}

    // @TODO add this to IProposal
    function printCalldata(Addresses) public virtual {}
}
