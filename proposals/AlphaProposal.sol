pragma solidity ^0.8.0;

import {Strings} from "@openzeppelin/utils/Strings.sol";

import {Vm, VmSafe} from "@forge-std/Vm.sol";

import {Proposal} from "./Proposal.sol";
import {Constants} from "@utils/Constants.sol";
import {Addresses} from "@addresses/Addresses.sol";

abstract contract AlphaProposal is Proposal {
    using Strings for string;

    /// @notice starting snapshot of the contract state before the calls are made
    uint256 private _startSnapshot;

    /// @notice to be used by the build function easily create a governance proposal
    modifier buildModifier(address caller, Addresses addresses) {
        _startBuild(caller);
        _;
        _endBuild(addresses);
    }

    /// @notice to be used by the build function to create a governance proposal
    /// kick off the process of creating a governance proposal by:
    ///  1). taking a snapshot of the current state of the contract
    ///  2). starting prank as the caller
    ///  3). starting a recording of all calls created during the proposal
    function _startBuild(address caller) internal {
        _startSnapshot = vm.snapshot();
        vm.startPrank(caller);
        vm.record();
    }

    /// @notice to be used at the end of the build function to snapshot
    /// the actions performed by the proposal and revert these changes
    /// then, stop the prank and record the actions that were taken by the proposal.
    function _endBuild(Addresses addresses) internal {
        vm.stopPrank();
        /// roll back all state changes made during the governance proposal
        vm.revertTo(_startSnapshot);
        VmSafe.AccountAccess[] memory accountAccesses = vm
            .stopAndReturnStateDiff();

        for (uint256 i = 0; i < accountAccesses.length; i++) {
            /// only care about calls, static calls are ignored
            /// calls to and from Addresses contract are ignored
            if (
                accountAccesses[i].kind == VmSafe.AccountAccessKind.Call &&
                accountAccesses[i].account != address(addresses) &&
                accountAccesses[i].accessor != address(addresses)
            ) {
                _pushAction(
                    accountAccesses[i].value,
                    accountAccesses[i].account,
                    accountAccesses[i].data,
                    string(
                        abi.encodePacked(
                            "calling ",
                            accountAccesses[i].account,
                            " with ",
                            accountAccesses[i].value,
                            " eth and ",
                            accountAccesses[i].data,
                            " data."
                        )
                    )
                );
            }
        }
    }
}
