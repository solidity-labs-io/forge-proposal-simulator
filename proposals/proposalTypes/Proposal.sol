pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {IProposal} from "@proposals/proposalTypes/IProposal.sol";
import {Script} from "@forge-std/Script.sol";

abstract contract Proposal is Test, Script, IProposal {
    Action[] public actions;

    uint256 private PRIVATE_KEY;
    bool private DEBUG;
    bool private DO_DEPLOY;
    bool private DO_AFTER_DEPLOY;
    bool private DO_AFTER_DEPLOY_SETUP;
    bool private DO_BUILD;
    bool private DO_RUN;
    bool private DO_TEARDOWN;
    bool private DO_VALIDATE;
    bool private DO_PRINT;

    address public executor;

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

        // @TODO maybe we could call execute here
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

    function _pushAction(uint256 value, address target, bytes memory data)  internal {
        _pushAction(value, target, data, "");
    }

    function _pushAction(address target, bytes memory data) internal {
        _pushAction(0, target, data, "");
    }

    /// @notice simulate multisig proposal
    /// @param multisigAddress address of the multisig doing the calls
    function _simulateActions() internal {
        require(actions.length > 0, "Empty operation");

        vm.startPrank(executor);

        for (uint256 i = 0; i < actions.length; i++) {
            (bool success, bytes memory result) = actions[i].target.call{
                value: actions[i].value
            }(actions[i].arguments);

            require(success, string(result));
        }

        vm.stopPrank();
    }

    // @review maybe this should be public
    function _printActions() internal {
        for (uint256 i = 0; i < actions.length; i++) {
            log(actions[i].description);
        }
    }

    // @notice use this function to make validations before the proposal is executed
    // @dev optional to override, use to check the calldata ensure proposal doesn't doing anything unexpected
    function _preCheck() internal virtual {}

    // @notice use this function to make validations after the proposal is executed
    // @dev optional to override, use this to check the state of the contracts after the proposal is executed
    // @dev usually is conventional of a certain pattern being found in calldata to do the additional checks
    function _posCheck() internal virtual {}

    // @TODO add natspec
    function execute() public {
        executor = vm.addr(PRIVATE_KEY);

        vm.startBroadcast(PRIVATE_KEY);
        if (DO_DEPLOY) deploy();
        if (DO_AFTER_DEPLOY) afterDeploy();
        if (DO_AFTER_DEPLOY_SETUP) afterDeploySetup();
        vm.stopBroadcast();

        if (DO_BUILD) build();
        if (DO_RUN) run();
        if (DO_TEARDOWN) teardown();
        if (DO_VALIDATE) validate();
        if (DO_PRINT) {
            printCalldata();
            printProposalActionSteps();
        }

        delete executor;

     //@TODO rethink this
     //   if (DO_DEPLOY) {
     //       (
     //           string[] memory recordedNames,
     //           address[] memory recordedAddresses
     //       ) = addresses.getRecordedAddresses();
     //       for (uint256 i = 0; i < recordedNames.length; i++) {
     //           console.log("Deployed", recordedAddresses[i], recordedNames[i]);
     //       }

     //       console.log();

     //       for (uint256 i = 0; i < recordedNames.length; i++) {
     //           console.log('_addAddress("%s",', recordedNames[i]);
     //           console.log(block.chainid);
     //           console.log(", ");
     //           console.log(recordedAddresses[i]);
     //           console.log(");");
     //       }
     //   }
     }


        function deploy() public virtual;

        function afterDeploy() public virtual;

        function afterDeploySetup() public virtual;

        function build() public virtual;

        function run() public virtual;

        function printCalldata() public virtual;

        function teardown() public virtual;

        function validate() public virtual;

        function printProposalActionSteps() public virtual;



}
