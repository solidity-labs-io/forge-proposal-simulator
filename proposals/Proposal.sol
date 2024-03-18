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

    /// @notice debug flag to print proposal actions and steps
    bool internal DEBUG;

    /// @notice to be used by the build function easily create a governance proposal
    modifier buildModifier(address caller, Addresses addresses) {
        _startBuild(caller);
        _;
        _endBuild(caller, addresses);
    }

    /// @notice to be used by the build function to create a governance proposal
    /// kick off the process of creating a governance proposal by:
    ///  1). taking a snapshot of the current state of the contract
    ///  2). starting prank as the caller
    ///  3). starting a recording of all calls created during the proposal
    function _startBuild(address caller) private {
        _startSnapshot = vm.snapshot();
        vm.startPrank(caller);
        vm.startStateDiffRecording();
    }

    /// @notice to be used at the end of the build function to snapshot
    /// the actions performed by the proposal and revert these changes
    /// then, stop the prank and record the actions that were taken by the proposal.
    function _endBuild(address caller, Addresses addresses) private {
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
                accountAccesses[i].accessor == caller /// caller is correct, not a subcall
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

        for (uint256 i = 0; i < data.length; i++) {
            /// For each byte, find the corresponding hexadecimal characters
            buffer[i * 2] = characters[uint256(uint8(data[i] >> 4))];
            buffer[i * 2 + 1] = characters[uint256(uint8(data[i] & 0x0f))];
        }

        /// Convert the bytes array to a string and return
        return string(buffer);
    }

    /// @notice override this to set the proposal name
    function name() external view virtual returns (string memory);

    /// @notice override this to set the proposal description
    function description() public view virtual returns (string memory);

    /// @notice main function
    /// @dev do not override
    function run(Addresses addresses, address deployer) external {
        vm.startBroadcast(deployer);
        _deploy(addresses, deployer);
        _afterDeploy(addresses, deployer);
        vm.stopBroadcast();

        _build(addresses);
        _run(addresses, deployer);
        _teardown(addresses, deployer);
        _validate(addresses, deployer);
    }

    /// @notice main function with more granularity control
    /// @dev do not override
    function run(
        Addresses addresses,
        address deployer,
        bool doDeploy,
        bool doBuild,
        bool doAfterDeploy,
        bool doRun,
        bool doTeardown,
        bool doValidate
    ) external {
        vm.startBroadcast(deployer);

        if (doDeploy) {
            _deploy(addresses, deployer);
        }
        if (doAfterDeploy) {
            _afterDeploy(addresses, deployer);
        }

        vm.stopBroadcast();

        if (doBuild) {
            _build(addresses);
        }
        if (doRun) {
            _run(addresses, deployer);
        }
        if (doTeardown) {
            _teardown(addresses, deployer);
        }
        if (doValidate) {
            _validate(addresses, deployer);
        }
    }

    /// @dev set the debug flag
    function setDebug(bool debug) public {
        DEBUG = debug;
    }

    /// @notice Print proposal calldata
    function getCalldata() public virtual returns (bytes memory data);

    /// @notice Print out proposal actions
    /// @dev do not override
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

        if (DEBUG) {
            console.log("\n\nProposal Description:\n\n%s", description());
            console.log(
                "\n\n------------------ Proposal Actions ------------------"
            );
        }

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

            if (DEBUG) {
                console.log("%d). %s", i + 1, actions[i].description);
                console.log("target: %s\npayload", actions[i].target);
                console.logBytes(actions[i].arguments);
                console.log("\n");
            }
        }
    }

    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------
    /// ------------------------ Legacy FPS Support ------------------------
    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------

    /// @dev push an action to the proposal
    function _pushAction(
        uint256 value,
        address target,
        bytes memory data,
        string memory _description
    ) internal {
        actions.push(
            Action({
                value: value,
                target: target,
                arguments: data,
                description: _description
            })
        );
    }

    /// @dev push an action to the proposal with a value of 0
    function _pushAction(
        address target,
        bytes memory data,
        string memory _description
    ) internal {
        _pushAction(0, target, data, _description);
    }

    /// @dev push an action to the proposal with empty description
    function _pushAction(
        uint256 value,
        address target,
        bytes memory data
    ) internal {
        _pushAction(value, target, data, "");
    }

    /// @dev push an action to the proposal with a value of 0 and empty description
    function _pushAction(address target, bytes memory data) internal {
        _pushAction(0, target, data, "");
    }

    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------
    /// ------------------ Internal functions to override ------------------
    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------

    /// @dev Deploy contracts and add them to list of addresses
    function _deploy(Addresses, address) internal virtual {}

    /// @dev After deploying, call initializers and link contracts together
    function _afterDeploy(Addresses, address) internal virtual {}

    /// @dev After finishing deploy and deploy cleanup, build the proposal
    function _build(Addresses) internal virtual {}

    /// @dev Actually run the proposal (e.g. queue actions in the Timelock,
    /// or execute a serie of Multisig calls...).
    /// See proposals for helper contracts.
    /// address param is the address of the proposal executor
    function _run(Addresses, address) internal virtual {
        /// Check if there are actions to run
        uint256 actionsLength = actions.length;
        require(actionsLength > 0, "No actions found");
    }

    /// @dev After a proposal executed, if you mocked some behavior in the
    /// afterDeploy step, you might want to tear down the mocks here.
    /// For instance, in afterDeploy() you could impersonate the multisig
    /// of another protocol to do actions in their protocol (in anticipation
    /// of changes that must happen before your proposal execution), and here
    /// you could revert these changes, to make sure the integration tests
    /// run on a state that is as close to mainnet as possible.
    function _teardown(Addresses, address) internal virtual {}

    /// @dev For small post-proposal checks, e.g. read state variables of the
    /// contracts you deployed, to make sure your deploy() and afterDeploy()
    /// steps have deployed contracts in a correct configuration, or read
    /// states that are expected to have change during your run() step.
    /// Note that there is a set of tests that run post-proposal in
    /// contracts/test/integration/post-proposal-checks, as well as
    /// tests that read state before proposals & after, in
    /// contracts/test/integration/proposal-checks, so this validate()
    /// step should only be used for small checks.
    /// If you want to add extensive validation of a new component
    /// deployed by your proposal, you might want to add a post-proposal
    /// test file instead.
    function _validate(Addresses, address) internal virtual {}
}
