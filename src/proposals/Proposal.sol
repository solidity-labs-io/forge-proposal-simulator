pragma solidity ^0.8.0;

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

    struct TransferInfo {
        address to;
        uint256 value;
        address tokenAddress;
    }

    struct StateInfo {
        bytes32 slot;
        bytes32 oldValue;
        bytes32 newValue;
    }

    /// @notice transfers during proposal execution
    mapping(address addr => TransferInfo[] transfers) private _proposalTransfers;

    /// @notice state changes during proposal execution
    mapping(address addr => StateInfo[] stateChanges) private _stateInfos;

    /// @notice addresses involved in state changes or token transfers
    address[] private _proposalAffectedAddresses;

    /// @notice map if an address is affected in proposal execution
    mapping(address addr => bool isAffected) private _isProposalAffectedAddress;

    /// @notice starting snapshot of the contract state before the calls are made
    uint256 private _startSnapshot;

    /// @notice list of actions to be executed, regardless of proposal type
    /// they all follow the same structure
    Action[] public actions;

    /// @notice flag to print internal proposal logs, default is false
    bool internal DEBUG;
    /// @notice flag to trigger the deployment of contracts on-chain, default is true
    bool internal DO_DEPLOY;
    /// @notice flag to initiate pre-build mocking processes, default is true
    bool internal DO_PRE_BUILD_MOCK;
    /// @notice flag to transform plain solidity code into calldata encoded for the
    /// user's governance model, default is true
    bool internal DO_BUILD;
    /// @notice flag to simulate saved actions during the `build` step, default is true
    bool internal DO_SIMULATE;
    /// @notice flag to validate the system state post-proposal simulation, default is true
    bool internal DO_VALIDATE;
    /// @notice flag to print proposal description, actions, and calldata, default is true
    bool internal DO_PRINT;
    /// @notice flag to update the `Addresses.json` file with the newly added and changed
    /// addresses, default is false
    bool internal DO_UPDATE_ADDRESS_JSON;

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
        DO_PRE_BUILD_MOCK = vm.envOr("DO_PRE_BUILD_MOCK", true);
        DO_BUILD = vm.envOr("DO_BUILD", true);
        DO_SIMULATE = vm.envOr("DO_SIMULATE", true);
        DO_VALIDATE = vm.envOr("DO_VALIDATE", true);
        DO_PRINT = vm.envOr("DO_PRINT", true);
        DO_UPDATE_ADDRESS_JSON = vm.envOr("DO_UPDATE_ADDRESS_JSON", false);
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
        if (DO_DEPLOY) {
            /// DEPLOYER_EOA must be an unlocked account when running through forge script
            /// use cast wallet to unlock the account
            address deployer = addresses.getAddress("DEPLOYER_EOA");

            vm.startBroadcast(deployer);
            deploy();
            addresses.printJSONChanges();
            vm.stopBroadcast();
        }

        if (DO_PRE_BUILD_MOCK) preBuildMock();
        if (DO_BUILD) build();
        if (DO_SIMULATE) simulate();
        if (DO_VALIDATE) validate();
        if (DO_PRINT) print();
        if (DO_UPDATE_ADDRESS_JSON) addresses.updateJson();
    }

    /// @notice return proposal calldata.
    function getCalldata() public virtual returns (bytes memory data);

    /// @notice check and return proposal id if there are any on-chain proposal that matches the
    /// proposal calldata
    function getProposalId() public view virtual returns (uint256 proposalId);

    /// @notice get proposal actions
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
                actions[i].target != address(0), "Invalid target for proposal"
            );
            /// if there are no args and no eth, the action is not valid
            require(
                (actions[i].arguments.length == 0 && actions[i].value > 0)
                    || actions[i].arguments.length > 0,
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

    /// @notice helper function to mock on-chain data before build
    ///         e.g. pranking, etching, etc.
    function preBuildMock() public virtual {}

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
            console.log(
                "target: %s\npayload", _getAddressLabel(actions[i].target)
            );
            console.logBytes(actions[i].arguments);
            console.log("\n");
        }

        console.log("\n----------------- Proposal Changes -------------------");
        for (uint256 i; i < _proposalAffectedAddresses.length; i++) {
            address account = _proposalAffectedAddresses[i];

            console.log(
                "\n\n", string(abi.encodePacked(_getAddressLabel(account), ":"))
            );

            // print token transfers
            TransferInfo[] memory transfers = _proposalTransfers[account];
            if (transfers.length > 0) {
                console.log("\n Transfers:");
            }
            for (uint256 j; j < transfers.length; j++) {
                if (transfers[j].tokenAddress == address(0)) {
                    console.log(
                        string(
                            abi.encodePacked(
                                "Sent ",
                                vm.toString(transfers[j].value),
                                " ETH to ",
                                _getAddressLabel(transfers[j].to)
                            )
                        )
                    );
                } else {
                    console.log(
                        string(
                            abi.encodePacked(
                                "Sent ",
                                vm.toString(transfers[j].value),
                                " ",
                                _getAddressLabel(transfers[j].tokenAddress),
                                " to ",
                                _getAddressLabel(transfers[j].to)
                            )
                        )
                    );
                }
            }

            // print state changes
            StateInfo[] memory stateChanges = _stateInfos[account];
            if (stateChanges.length > 0) {
                console.log("\n State Changes:");
            }
            for (uint256 j; j < stateChanges.length; j++) {
                console.log("Slot:", vm.toString(stateChanges[j].slot));
                console.log("- ", vm.toString(stateChanges[j].oldValue));
                console.log("+ ", vm.toString(stateChanges[j].newValue));
            }
        }

        _printProposalCalldata();
    }

    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------
    /// ------------------------- Internal functions -----------------------
    /// --------------------------------------------------------------------
    /// --------------------------------------------------------------------

    /// @notice validate actions inclusion
    /// default implementation check for duplicate actions
    function _validateAction(address target, uint256 value, bytes memory data)
        internal
        virtual
    {
        uint256 actionsLength = actions.length;
        for (uint256 i = 0; i < actionsLength; i++) {
            // Check if the target, arguments and value matches with other exciting actions.
            bool isDuplicateTarget = actions[i].target == target;
            bool isDuplicateArguments =
                keccak256(actions[i].arguments) == keccak256(data);
            bool isDuplicateValue = actions[i].value == value;

            require(
                !(isDuplicateTarget && isDuplicateArguments && isDuplicateValue),
                "Duplicated action found"
            );
        }
    }

    /// @notice validate actions
    function _validateActions() internal virtual {}

    /// @notice print proposal calldata
    function _printProposalCalldata() internal virtual {
        console.log(
            "\n\n------------------ Proposal Calldata ------------------"
        );
        console.logBytes(getCalldata());
    }

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
    /// then, stop the prank and record the state diffs and actions that
    /// were taken by the proposal.
    /// @param caller the address that will be used as the caller for the
    /// actions, e.g. multisig address, timelock address, etc.
    function _endBuild(address caller) private {
        VmSafe.AccountAccess[] memory accountAccesses =
            vm.stopAndReturnStateDiff();

        vm.stopPrank();

        /// roll back all state changes made during the governance proposal
        require(
            vm.revertTo(_startSnapshot),
            "failed to revert back to snapshot, unsafe state to run proposal"
        );

        _processStateDiffChanges(accountAccesses);

        for (uint256 i = 0; i < accountAccesses.length; i++) {
            /// only care about calls from the original caller,
            /// static calls are ignored,
            /// calls to and from Addresses and the vm contract are ignored
            if (
                accountAccesses[i].account != address(addresses)
                    && accountAccesses[i].account != address(vm)
                /// ignore calls to vm in the build function
                && accountAccesses[i].accessor != address(addresses)
                    && accountAccesses[i].kind == VmSafe.AccountAccessKind.Call
                    && accountAccesses[i].accessor == caller
            ) {
                /// caller is correct, not a subcall
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
                                _getAddressLabel(accountAccesses[i].account),
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

    /// @notice helper method to get transfers and state changes of proposal affected addresses
    function _processStateDiffChanges(
        VmSafe.AccountAccess[] memory accountAccesses
    ) internal {
        for (uint256 i = 0; i < accountAccesses.length; i++) {
            // process ETH transfer changes
            _processETHTransferChanges(accountAccesses[i]);

            // process ERC20 transfer changes
            _processERC20TransferChanges(accountAccesses[i]);

            // process state changes
            _processStateChanges(accountAccesses[i].storageAccesses);
        }
    }

    /// @notice helper method to get eth transfers of proposal affected addresses
    function _processETHTransferChanges(
        VmSafe.AccountAccess memory accountAccess
    ) internal {
        address account = accountAccess.account;
        // get eth transfers
        if (accountAccess.value != 0) {
            // add address to proposal affected addresses array only if not already added
            if (!_isProposalAffectedAddress[accountAccess.accessor]) {
                _isProposalAffectedAddress[accountAccess.accessor] = true;
                _proposalAffectedAddresses.push(accountAccess.accessor);
            }
            _proposalTransfers[accountAccess.accessor].push(
                TransferInfo({
                    to: account,
                    value: accountAccess.value,
                    tokenAddress: address(0)
                })
            );
        }
    }

    /// @notice helper method to get ERC20 token transfers of proposal affected addresses
    function _processERC20TransferChanges(
        VmSafe.AccountAccess memory accountAccess
    ) internal {
        bytes memory data = accountAccess.data;
        if (data.length <= 4) {
            return;
        }

        // get function selector from calldata
        bytes4 selector = bytes4(data);

        // get function params
        bytes memory params = new bytes(data.length - 4);
        for (uint256 j = 0; j < data.length - 4; j++) {
            params[j] = data[j + 4];
        }

        address from;
        address to;
        uint256 value;
        // 'transfer' selector in ERC20 token
        if (selector == 0xa9059cbb) {
            (to, value) = abi.decode(params, (address, uint256));
            from = accountAccess.accessor;
        }
        // 'transferFrom' selector in ERC20 token
        else if (selector == 0x23b872dd) {
            (from, to, value) = abi.decode(params, (address, address, uint256));
        } else {
            return;
        }

        // add address to proposal affected addresses array only if not already added
        if (!_isProposalAffectedAddress[from]) {
            _isProposalAffectedAddress[from] = true;
            _proposalAffectedAddresses.push(from);
        }

        _proposalTransfers[from].push(
            TransferInfo({
                to: to,
                value: value,
                tokenAddress: accountAccess.account
            })
        );
    }

    /// @notice helper method to get state changes of proposal affected addresses
    function _processStateChanges(VmSafe.StorageAccess[] memory storageAccess)
        internal
    {
        for (uint256 i; i < storageAccess.length; i++) {
            address account = storageAccess[i].account;

            // get only state changes for write storage access
            if (storageAccess[i].isWrite) {
                _stateInfos[account].push(
                    StateInfo({
                        slot: storageAccess[i].slot,
                        oldValue: storageAccess[i].previousValue,
                        newValue: storageAccess[i].newValue
                    })
                );
            }

            // add address to proposal affected addresses array only if not already added
            if (
                !_isProposalAffectedAddress[account]
                    && _stateInfos[account].length != 0
            ) {
                _isProposalAffectedAddress[account] = true;
                _proposalAffectedAddresses.push(account);
            }
        }
    }

    /// @notice helper method to get labels for addresses
    function _getAddressLabel(address contractAddress)
        internal
        view
        returns (string memory)
    {
        string memory label = vm.getLabel(contractAddress);

        bytes memory prefix = bytes("unlabeled:");
        bytes memory strBytes = bytes(label);

        if (strBytes.length >= prefix.length) {
            // check if address is unlabeled
            for (uint256 i = 0; i < prefix.length; i++) {
                if (strBytes[i] != prefix[i]) {
                    // return "{LABEL} @{ADDRESS}" if address is labeled
                    return string(
                        abi.encodePacked(
                            label, " @", vm.toString(contractAddress)
                        )
                    );
                }
            }
        } else {
            // return "{LABEL} @{ADDRESS}" if address is labeled
            return string(
                abi.encodePacked(label, " @", vm.toString(contractAddress))
            );
        }

        // return "UNLABELED @{ADDRESS}" if address is unlabeled
        return string(
            abi.encodePacked("UNLABELED @", vm.toString(contractAddress))
        );
    }
}
