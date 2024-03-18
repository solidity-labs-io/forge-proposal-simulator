pragma solidity ^0.8.0;

import {Strings} from "@openzeppelin/utils/Strings.sol";

import {VmSafe} from "@forge-std/Vm.sol";

import {Proposal} from "@proposals/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

abstract contract AlphaProposal is Proposal {
    using Strings for *;

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
        vm.startStateDiffRecording();
    }

    /// @notice to be used at the end of the build function to snapshot
    /// the actions performed by the proposal and revert these changes
    /// then, stop the prank and record the actions that were taken by the proposal.
    function _endBuild(Addresses addresses) internal {
        vm.stopPrank();
        VmSafe.AccountAccess[] memory accountAccesses = vm
            .stopAndReturnStateDiff();
        /// roll back all state changes made during the governance proposal
        vm.revertTo(_startSnapshot);

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
                            accountAccesses[i].account.toHexString(),
                            " with ",
                            accountAccesses[i].value.toString(),
                            " eth and ",
                            _bytesToString(accountAccesses[i].data),
                            " data."
                        )
                    )
                );
            }
        }
    }

    /// @notice convert bytes to a string
    /// @param data the bytes to convert to a human readable string
    function _bytesToString(
        bytes memory data
    ) private pure returns (string memory) {
        /// Initialize an array of characters twice the length of data,
        /// since each byte will be represented by two hexadecimal characters
        bytes memory buffer = new bytes(data.length * 2);

        /// Characters for conversion
        bytes memory characters = "0123456789abcdef";

        for (uint i = 0; i < data.length; i++) {
            /// For each byte, find the corresponding hexadecimal characters
            buffer[i * 2] = characters[uint(uint8(data[i] >> 4))];
            buffer[i * 2 + 1] = characters[uint(uint8(data[i] & 0x0f))];
        }

        /// Convert the bytes array to a string and return
        return string(buffer);
    }
}
