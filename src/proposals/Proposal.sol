pragma solidity =0.8.25;

import {Test} from "@forge-std/Test.sol";
import {VmSafe} from "@forge-std/Vm.sol";
import {console} from "@forge-std/console.sol";

import {Script} from "@forge-std/Script.sol";
import {IProposal} from "@proposals/IProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

abstract contract Proposal is Test, Script, IProposal {
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

    /// @notice debug flag to print internal proposal logs
    bool internal DEBUG;
    bool internal DO_DEPLOY;
    bool internal DO_AFTER_DEPLOY_MOCK;
    bool internal DO_BUILD;
    bool internal DO_SIMULATE;
    bool internal DO_VALIDATE;
    bool internal DO_PRINT;

    /// @notice Addresses contract
    Addresses public addresses;

    /// @notice primary fork id
    uint256 public primaryForkId;

    /// @notice buildModifier to be used by the build function to populate the
    /// actions array
    /// @param toPrank the address that will be used as the caller for the
    /// actions, e.g. multisig address, timelock address, etc.
    modifier buildModifier(address toPrank) {
        _startBuild(toPrank);
        _;
        _endBuild(toPrank);
    }

    constructor() {
        DEBUG = vm.envOr("DEBUG", false);

        DO_DEPLOY = vm.envOr("DO_DEPLOY", true);
        DO_AFTER_DEPLOY_MOCK = vm.envOr("DO_AFTER_DEPLOY_MOCK", true);
        DO_BUILD = vm.envOr("DO_BUILD", true);
        DO_SIMULATE = vm.envOr("DO_SIMULATE", true);
        DO_VALIDATE = vm.envOr("DO_VALIDATE", true);
        DO_PRINT = vm.envOr("DO_PRINT", true);
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
    function run() public virtual {
        vm.selectFork(primaryForkId);

        if (DO_DEPLOY) {
            /// DEPLOYER_EOA must be an unlocked account when running through forge script
            /// use cast wallet to unlock the account
            address deployer = addresses.getAddress("DEPLOYER_EOA");

            vm.startBroadcast(deployer);
            deploy();
            addresses.printJSONChanges();
            vm.stopBroadcast();
        }

        if (DO_AFTER_DEPLOY_MOCK) afterDeployMock();
        if (DO_BUILD) build();
        if (DO_SIMULATE) simulate();
        if (DO_VALIDATE) validate();
        if (DO_PRINT) print();
    }

    /// @notice return proposal calldata.
    function getCalldata() public virtual returns (bytes memory data);

    /// @notice check if there are any on-chain proposal that matches the
    /// proposal calldata
    function checkOnChainCalldata() public view virtual returns (bool matches);

    /// @notice get proposal actions
    /// @dev do not override
    function getProposalActions()
        public
        view
        virtual
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

    /// @notice set the Addresses contract
    function setAddresses(Addresses _addresses) public override {
        addresses = _addresses;
    }

    /// @notice set the primary fork id
    function setPrimaryForkId(uint256 _primaryForkId) public override {
        primaryForkId = _primaryForkId;
    }

    /// @notice deploy any contracts needed for the proposal.
    /// @dev contracts calls here are broadcast if the broadcast flag is set.
    function deploy() public virtual {}

    /// @notice helper function to mock on-chain data after deployment
    ///         e.g. pranking, etching, etc.
    function afterDeployMock() public virtual {}

    /// @notice build the proposal actions
    /// @dev contract calls must be perfomed in plain solidity.
    ///      overriden requires using buildModifier modifier to leverage
    ///      foundry snapshot and state diff recording to populate the actions array.
    function build() public virtual {}

    /// @notice actually simulates the proposal.
    ///         e.g. schedule and execute on Timelock Controller,
    ///         proposes, votes and execute on Governor Bravo, etc.
    function simulate() public virtual {}

    /// @notice execute post-proposal checks.
    ///          e.g. read state variables of the deployed contracts to make
    ///          sure they are deployed and initialized correctly, or read
    ///          states that are expected to have changed during the simulate step.
    function validate() public virtual {}

    /// @notice print proposal description, actions and calldata
    function print() public virtual {
        console.log("\n---------------- Proposal Description ----------------");
        console.log(description());

        console.log("\n------------------ Proposal Actions ------------------");
        for (uint256 i; i < actions.length; i++) {
            console.log("%d). %s", i + 1, actions[i].description);
            console.log("target: %s\npayload", actions[i].target);
            console.logBytes(actions[i].arguments);
            console.log("\n");
        }

        console.log(
            "\n\n------------------ Proposal Calldata ------------------"
        );
        console.logBytes(getCalldata());
    }

    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------
    /// ------------------------- Internal functions -----------------------
    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------

    /// @notice validate actions inclusion
    /// default implementation check for duplicate actions
    function _validateAction(
        address target,
        uint256 value,
        bytes memory data
    ) internal virtual {
        // uses transition storage to check for duplicate actions
        bytes32 actionHash = keccak256(abi.encodePacked(target, value, data));

        uint256 found;

        assembly {
            found := tload(actionHash)
        }

        require(found == 0, "Duplicated action found");

        assembly {
            tstore(actionHash, 1)
        }
    }

    /// @notice validate actions
    function _validateActions() internal virtual {}

    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------
    /// ------------------------- Private functions ------------------------
    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------

    /// @notice to be used by the build function to create a governance proposal
    /// kick off the process of creating a governance proposal by:
    ///  1). taking a snapshot of the current state of the contract
    ///  2). starting prank as the caller
    ///  3). starting a $recording of all calls created during the proposal
    /// @param toPrank the address that will be used as the caller for the
    /// actions, e.g. multisig address, timelock address, etc.
    function _startBuild(address toPrank) private {
        vm.startPrank(toPrank);

        _startSnapshot = vm.snapshot();

        vm.startStateDiffRecording();
    }

    /// @notice to be used at the end of the build function to snapshot
    /// the actions performed by the proposal and revert these changes
    /// then, stop the prank and record the actions that were taken by the proposal.
    /// @param caller the address that will be used as the caller for the
    /// actions, e.g. multisig address, timelock address, etc.
    function _endBuild(address caller) private {
        VmSafe.AccountAccess[] memory accountAccesses = vm
            .stopAndReturnStateDiff();

        vm.stopPrank();

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
                accountAccesses[i].account != address(vm) &&
                /// ignore calls to vm in the build function
                accountAccesses[i].accessor != address(addresses) &&
                accountAccesses[i].kind == VmSafe.AccountAccessKind.Call &&
                accountAccesses[i].accessor == caller /// caller is correct, not a subcall
            ) {
                _validateAction(
                    accountAccesses[i].account,
                    accountAccesses[i].value,
                    accountAccesses[i].data
                );

                actions.push(
                    Action({
                        value: accountAccesses[i].value,
                        target: accountAccesses[i].account,
                        arguments: accountAccesses[i].data,
                        description: string(
                            abi.encodePacked(
                                "calling ",
                                vm.toString(accountAccesses[i].account),
                                " with ",
                                vm.toString(accountAccesses[i].value),
                                " eth and ",
                                vm.toString(accountAccesses[i].data),
                                " data."
                            )
                        )
                    })
                );
            }
        }

        _validateActions();
    }
}
