pragma solidity ^0.8.0;

import {Strings} from "@openzeppelin/utils/Strings.sol";

import {Test} from "@forge-std/Test.sol";
import {VmSafe} from "@forge-std/Vm.sol";
import {console} from "@forge-std/console.sol";

import {Script} from "@forge-std/Script.sol";
import {IProposal} from "@proposals/IProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

abstract contract Proposal is Test, Script, IProposal {
    using Strings for *;

    struct Action {
        address target;
        uint256 value;
        bytes arguments;
        string description;
    }

    /// @notice starting snapshot of the contract state before the calls are made
    uint256 private _startSnapshot;

    /// @notice list of actions to be executed, regardless of proposal type
    /// they all follow the same structure
    Action[] public actions;

    /// @notice debug flag to print proposal actions, calldata, new addresses and changed addresses
    /// @dev default is true
    bool internal DEBUG = false;

    /// @notice Addresses contract
    Addresses public addresses;

    /// @notice the actions caller name in the Addresses JSON
    string public caller;

    ///@notice primary fork id
    uint256 public primaryForkId;

    modifier buildModifier() {
        _startBuild();
        _;
        _endBuild();
    }

    /// @param addressesPath the path to the Addresses JSON file.
    /// @param _caller the contract/EOA name recorded in Addresses JSON that will execute the proposal on-chain .
    constructor(string memory addressesPath, string memory _caller) {
        addresses = new Addresses(addressesPath);
        vm.makePersistent(address(addresses));
        caller = _caller;
        DEBUG = vm.envOr("DEBUG", false);
    }

    /// @notice proposal name, e.g. "BIP15".
    /// @dev override this to set the proposal name.
    function name() external view virtual returns (string memory);

    /// @notice proposal description.
    /// @dev override this to set the proposal description.
    function description() public view virtual returns (string memory);

    /// @notice function to be used by forge script.
    /// @dev use flags to determine which actions to take
    ///      this function shoudn't be overriden.
    function run() external {
        vm.selectFork(primaryForkId);

        /// DEV must be an unlocked account when running through forge script
        /// use cast wallet to unlock the account
        address deployer = addresses.getAddress("DEV");

        vm.startBroadcast(deployer);
        deploy();
        afterDeploy();
        vm.stopBroadcast();

        build();
        simulate();
        validate();

        if (DEBUG) {
            printRecordedAddresses();
            printActions();
            printCalldata();
        }
    }

    /// @notice return proposal calldata.
    function getCalldata() public virtual returns (bytes memory data);

    /// @notice return proposal actions.
    /// @dev this function shoudn't be overriden.
    function getProposalActions()
        public
        view
        override
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory arguments
        )
    {
        uint256 actionsLength = actions.length;
        require(actionsLength > 0, "No actions found");

        targets = new address[](actionsLength);
        values = new uint256[](actionsLength);
        arguments = new bytes[](actionsLength);

        for (uint256 i; i < actionsLength; i++) {
            require(
                actions[i].target != address(0),
                "Invalid target for proposal"
            );
            /// if there are no args and no eth, the action is not valid
            require(
                (actions[i].arguments.length == 0 && actions[i].value > 0) ||
                    actions[i].arguments.length > 0,
                "Invalid arguments for proposal"
            );
            targets[i] = actions[i].target;
            arguments[i] = actions[i].arguments;
            values[i] = actions[i].value;
        }
    }

    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------
    /// --------------------------- Public functions -----------------------
    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------

    /// @notice deploy any contracts needed for the proposal.
    /// @dev contracts calls here are broadcast if the broadcast flag is set.
    function deploy() public virtual {}

    /// @notice helper function to take any needed actions after deployment
    ///         e.g. initialize contracts, transfer ownership, etc.
    /// @dev contracts calls here are broadcast if the broadcast flag is set
    function afterDeploy() public virtual {}

    /// @notice build the proposal actions
    /// @dev contract calls must be perfomed in plain solidity.
    ///      overriden requires using buildModifier modifier to leverage
    ///      foundry snapshot and state diff recording to populate the actions array.
    function build() public virtual {}

    /// @notice actually simulates the proposal.
    ///         e.g. schedule and execute on Timelock Controller,
    ///         proposes, votes and execute on Governor Bravo, etc.
    function simulate() public virtual {
        /// Check if there are actions to run
        uint256 actionsLength = actions.length;
        require(actionsLength > 0, "No actions found");

        for (uint256 i = 0; i < actionsLength; i++) {
            for (uint256 j = i + 1; j < actionsLength; j++) {
                // Check if either the target or the arguments are the same for any two actions
                bool isDuplicateTarget = actions[i].target == actions[j].target;
                bool isDuplicateArguments = keccak256(actions[i].arguments) ==
                    keccak256(actions[j].arguments);

                require(
                    !(isDuplicateTarget && isDuplicateArguments),
                    "Duplicate actions found"
                );
            }
        }
    }

    /// @notice execute post-proposal checks.
    ///          e.g. read state variables of the deployed contracts to make
    ///          sure they are deployed and initialized correctly, or read
    ///          states that are expected to have changed during the simulate step.
    function validate() public virtual {}

    /// @notice print proposal calldata
    function printCalldata() public virtual {
        console.log(
            "\n\n------------------ Proposal Calldata ------------------"
        );
        console.logBytes(getCalldata());
    }

    /// @notice print proposal actions
    function printActions() public view {
        console.log("\n---------------- Proposal Description ----------------");
        console.log(description());
        console.log("\n------------------ Proposal Actions ------------------");
        for (uint256 i; i < actions.length; i++) {
            console.log("%d). %s", i + 1, actions[i].description);
            console.log("target: %s\npayload", actions[i].target);
            console.logBytes(actions[i].arguments);
            console.log("\n");
        }
    }

    /// @notice print recorded and changed addresses
    function printRecordedAddresses() public view {
        (
            string[] memory recordedNames,
            ,
            address[] memory recordedAddresses
        ) = addresses.getRecordedAddresses();

        if (recordedNames.length > 0) {
            console.log(
                "\n-------- Addresses added after running proposal --------"
            );
            for (uint256 j = 0; j < recordedNames.length; j++) {
                console.log(
                    "{\n          'addr': '%s', ",
                    recordedAddresses[j]
                );
                console.log("        'chainId': %d,", block.chainid);
                console.log("        'isContract': %s", true, ",");
                console.log(
                    "        'name': '%s'\n}%s",
                    recordedNames[j],
                    j < recordedNames.length - 1 ? "," : ""
                );
            }
        }

        (
            string[] memory changedNames,
            ,
            ,
            address[] memory changedAddresses
        ) = addresses.getChangedAddresses();

        if (changedNames.length > 0) {
            console.log(
                "\n------- Addresses changed after running proposal --------"
            );

            for (uint256 j = 0; j < changedNames.length; j++) {
                console.log("{\n          'addr': '%s', ", changedAddresses[j]);
                console.log("        'chainId': %d,", block.chainid);
                console.log("        'isContract': %s", true, ",");
                console.log(
                    "        'name': '%s'\n}%s",
                    changedNames[j],
                    j < changedNames.length - 1 ? "," : ""
                );
            }
        }
    }

    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------
    /// -------------------------- Private functions -------------------------
    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------

    /// @notice to be used by the build function to create a governance proposal
    /// kick off the process of creating a governance proposal by:
    ///  1). taking a snapshot of the current state of the contract
    ///  2). starting prank as the caller
    ///  3). starting a $recording of all calls created during the proposal
    function _startBuild() private {
        _startSnapshot = vm.snapshot();
        vm.startPrank(addresses.getAddress(caller));
        vm.startStateDiffRecording();
    }

    /// @notice to be used at the end of the build function to snapshot
    /// the actions performed by the proposal and revert these changes
    /// then, stop the prank and record the actions that were taken by the proposal.
    function _endBuild() private {
        vm.stopPrank();
        VmSafe.AccountAccess[] memory accountAccesses = vm
            .stopAndReturnStateDiff();

        /// roll back all state changes made during the governance proposal
        require(
            vm.revertTo(_startSnapshot),
            "failed to revert back to snapshot, unsafe state to run proposal"
        );

        for (uint256 i = 0; i < accountAccesses.length; i++) {
            /// only care about calls from the original caller,
            /// static calls are ignored,
            /// calls to and from Addresses and the vm contract are ignored
            if (
                accountAccesses[i].account != address(addresses) &&
                accountAccesses[i].account != address(vm) && /// ignore calls to vm in the build function
                accountAccesses[i].accessor != address(addresses) &&
                accountAccesses[i].kind == VmSafe.AccountAccessKind.Call &&
                accountAccesses[i].accessor == addresses.getAddress(caller) /// caller is correct, not a subcall
            ) {
                actions.push(
                    Action({
                        value: accountAccesses[i].value,
                        target: accountAccesses[i].account,
                        arguments: accountAccesses[i].data,
                        description: string(
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
                    })
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

        for (uint256 i = 0; i < data.length; i++) {
            /// For each byte, find the corresponding hexadecimal characters
            buffer[i * 2] = characters[uint256(uint8(data[i] >> 4))];
            buffer[i * 2 + 1] = characters[uint256(uint8(data[i] & 0x0f))];
        }

        /// Convert the bytes array to a string and return
        return string(buffer);
    }
}
