pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {IProposal} from "@proposals/proposalTypes/IProposal.sol";
import {StandardProposal} from "@proposals/StandardProposal.s.sol";

abstract contract Proposal is Test, StandardProposal, IProposal {
    Action[] public actions;

    bool internal DEBUG;

    constructor(string memory addressesPath) StandardProposal(addressesPath) {
        DEBUG = vm.envOr("DEBUG", true);
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

    /// @notice simulate proposal
    /// @param multisigAddress address of the account doing the calls
    function _simulateActions(address caller) internal override {
        require(actions.length > 0, "Empty Multisig operation");

        _before();
        vm.startPrank(caller);

        for (uint256 i = 0; i < actions.length; i++) {
            (bool success, bytes memory result) = actions[i].target.call{
                value: actions[i].value
            }(actions[i].arguments);

            require(success, string(result));
        }

        vm.stopPrank();
        _after();
    }

    // @review maybe this should be public
    function _printActions() internal {
        for (uint256 i = 0; i < actions.length; i++) {
            log(actions[i].description);
        }
    }

    // @notice use this function to make validations before the proposal is executed
    // @dev optional to override, use to check the calldata ensure proposal doesn't doing anything unexpected
    function _before() internal virtual {}

    // @notice use this function to make validations after the proposal is executed
    // @dev optional to override, use this to check the state of the contracts after the proposal is executed
    // @dev usually is conventional of a certain pattern being found in calldata to do the additional checks
    function _after() internal virtual {}

}
