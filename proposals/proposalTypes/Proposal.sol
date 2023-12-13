pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {IProposal} from "@proposals/proposalTypes/IProposal.sol";
import {StandardProposal} from "@proposals/StandardProposal.s.sol";

abstract contract Proposal is Test, StandardProposal, IProposal {
    Action[] public actions;

    bool internal DEBUG;

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

    /// @notice simulate proposal
    /// @param multisigAddress address of the account doing the calls
    function _simulateActions(address caller) internal override {
        require(actions.length > 0, "Empty Multisig operation");

        vm.startPrank(caller);

        for (uint256 i = 0; i < actions.length; i++) {
            (bool success, bytes memory result) = actions[i].target.call{
                value: actions[i].value
            }(actions[i].arguments);

            require(success, string(result));
        }

        vm.stopPrank();
    }

    function _simulateActions(uint256 addr1, uint256 addr2, uint256 addr3) internal {}

    // @review maybe this should be public
    function _printActions() internal {
        for (uint256 i = 0; i < actions.length; i++) {
            log(actions[i].description);
        }
    }
}
