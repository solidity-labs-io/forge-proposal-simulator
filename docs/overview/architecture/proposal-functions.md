The [Proposal.sol](../../../src/proposals/Proposal.sol) file contains a set of functions that all governance models inherit. Currently, there are four governance models inheriting from Proposal.sol: Bravo, Multisig, Timelock, and OpenZeppelin Governor. When using FPS for any of the aforementioned models to create proposals, all that needs to be done is to inherit one of the proposal types, such as [GovernorBravoProposal.sol](../../../src/proposals/GovernorBravoProposal.sol), and override the necessary functions to create the proposal, like `build` and `deploy`. FPS is flexible enough so that for any different governance model, governance proposal types can be easily adjusted to fit into the governance architecture. An example has been provided using [Arbitrum Governance](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/arbitrum/ArbitrumProposal.sol) on the FPS example repo to demonstrate FPS flexibility. The following is a list of functions proposals can implement:

-   `function name() public`: This function is empty in the `Proposal` contract.

    ```solidity
    function name() external view virtual returns (string memory);
    ```

    Override this function in the proposal-specific contract to define the proposal name. For example:

    ```solidity
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }
    ```

-   `function description() public`: This function is empty in the `Proposal` contract.

    ```solidity
    function description() public view virtual returns (string memory);
    ```

    Override this function in the proposal-specific contract to define the proposal description. For example:

    ```solidity
    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
    }
    ```

-   `function deploy() public`: This function is empty in the `Proposal` contract.

    ```solidity
    function deploy() public virtual {}
    ```

    Override this function when there are deployments to be made in the proposal. Here is an example from a [governor bravo proposal](../../guides/governor-bravo-proposal.md) demonstrating how to deploy two contracts, Vault and Token, if they are not already deployed.

    ```solidity
    function deploy() public override {
        address owner = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

        if (!addresses.isAddressSet("BRAVO_VAULT")) {
            // Here the vault is deployed
            Vault bravoVault = new Vault();

            addresses.addAddress("BRAVO_VAULT", address(bravoVault), true);
            bravoVault.transferOwnership(owner);
        }

        if (!addresses.isAddressSet("BRAVO_VAULT_TOKEN")) {
            // Here the token is deployed
            Token token = new Token();
            addresses.addAddress("BRAVO_VAULT_TOKEN", address(token), true);
            token.transferOwnership(owner);

            uint256 balance = token.balanceOf(address(this)) > 0
                ? token.balanceOf(address(this))
                : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));

            token.transfer(address(owner), balance);
        }
    }
    ```

    Deployments are done by `DEPLOYER_EOA` when running through a proposal `forge script,` and therefore, an address with this exact name must exist in the Addresses.json file. Foundry can be leveraged to actually broadcast the deployments when using the `broadcast` flag combined with `--account` flag. Please refer to the [foundry docs](https://book.getfoundry.sh/tutorials/best-practices?highlight=broadcast#scripts) for further assistance. Alternatively, when proposals are executed through `forge script,` the deployer address is the proposal contract itself.

-   `function afterDeployMock() public`: Post-deployment mock actions. Such actions can include pranking, etching, etc.

<a id="#build-function"></a>

-   `function build() public`: this function is where most of the FPS magic happens. It utilizes foundry cheat codes to automatically transform plain solidity code into calldata encoded for the user's governance model. This calldata can then be proposed on the Governance contract, signed by the multisig signers, or scheduled on the Timelock. For instance, an action might involve pointing a proxy to a new implementation address after deploying the implementation in the 'deploy' function as a privileged admin role in the system.

    ```solidity
    function build() public virtual {}
    ```

    The `buildModifier` must be implemented when overriding so that FPS can store the actions to be used later on in the calldata generation. This modifier runs the `_startBuild()` function before `build()` and the `endBuild()` function after. This modifier also takes `toPrank` as a parameter, which represents the address used as the caller for the actions in the proposal, such as the multisig address or timelock address.

    In the `startBuild()` function, we set the prank to the caller address and take a snapshot of the initial state using Foundry's `vm.snapshot()` cheat code. Then, we initiate Foundry's `vm.startStateDiffRecording()` to start recording all function calls made after this step. The `build()` function is then executed, and all the build steps are recorded. Finally, `endBuild()` stops the state diff recording, retrieves all the call information, stops the prank, reverts the state to the initial snapshot, and filters out the calls made by the caller, ignoring any static calls. This process ensures that only the mutative calls made by the caller are filtered and stored in the actions array.

    ```solidity
    modifier buildModifier(address toPrank) {
        _startBuild(toPrank);
        _;
        _endBuild(toPrank);
    }
    /// @notice to be used by the build function to create a governance proposal
    /// kick off the process of creating a governance proposal by:
    ///  1). taking a snapshot of the current state of the contract
    ///  2). starting prank as the caller
    ///  3). starting a $recording of all calls created during the proposal
    /// @param toPrank the address that will be used as the caller for the
    /// actions, e.g., multisig address, timelock address, etc.
    function _startBuild(address toPrank) private {
        vm.startPrank(toPrank);

        _startSnapshot = vm.snapshot();

        vm.startStateDiffRecording();
    }

    /// @notice to be used at the end of the build function to snapshot
    /// the actions performed by the proposal and revert these changes
    /// then, stop the prank and record the actions that were taken by the proposal.
    /// @param caller the address that will be used as the caller for the
    /// actions, e.g., multisig address, timelock address, etc.
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

            _validateActions();
        }
    }
    ```

    For a clearer understanding, we can look at the Bravo proposal example snippet. Here, `build()` has the `buildModifier`, which takes `PROTOCOL_TIMELOCK_BRAVO` as the caller. Multiple calls are made in the `build()` function, but only the mutative calls made by the caller will be stored in the actions array. In this example, there are three mutative actions. First, the deployed token is whitelisted on the deployed vault. Second, the vault is approved to transfer some `balance` on behalf of the Bravo timelock contract. Third, the `balance` amount of tokens is deposited in the vault from the Bravo timelock contract.

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO"))
    {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get vault address.
        address bravoVault = addresses.getAddress("BRAVO_VAULT");

        // Get token address.
        address token = addresses.getAddress("BRAVO_VAULT_TOKEN");

        // Get Bravo timelock's token balance.
        uint256 balance = Token(token).balanceOf(
            addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO")
        );

        /// CALLS -- mutative and recorded

        // Whitelists the deployed token on the deployed vault.
        Vault(bravoVault).whitelistToken(token, true);

        // Approve the token for the vault.
        Token(token).approve(bravoVault, balance);

        // Deposit all tokens into the vault.
        Vault(bravoVault).deposit(token, balance);
    }
    ```

-   `_validateAction() internal virtual`: It ensures there are no duplicate actions. This method can be further override to include custom checks for a action.

    ```solidity
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
    ```

-   `_validateActions() internal virtual`: This method can be overridden to add custom checks on all actions of proposals. Eg. Number of actions should be 1, First action should be approval etc.

-   `function getProposalActions() public`: Retrieves the sequence of actions for a proposal. This function should not be overridden in most cases.

-   `function getCalldata() public`: Retrieves any generated governance proposal calldata. This function should not be overridden at the proposal contract level as it is already overridden in the proposal type contract.

-   `function simulate() public`: Executes the previously saved actions during the `build` step. This function's execution depends on the successful execution of the `build` function. On the Proposal contract, this function is empty.

    ```solidity
    function simulate() public virtual {}
    ```

    This function can be overridden at the governance-specific contract or the proposal-specific contract, depending on the type of proposal. For example, the Governor Bravo type overrides this function at the governance-specific contract, while the Timelock type overrides it at the proposal-specific contract. Here we will take a look at the Governor Bravo type example. In this example, we have a proposer address that proposes the proposal to the governance contract. It first transfers and delegates governance tokens that meet the minimum proposal threshold and quorum votes to itself. Then it registers the proposal, rolls the proposal to the Active state so that voting can begin, votes yes to the proposal, rolls to the block where the voting period has ended, and now the proposal is in the Succeeded state. Then it queues the proposal in the governance Timelock contract, warps to the end of the timelock delay period, and finally executes the proposal, thus simulating the complete proposal on the local fork.

    ```solidity
    function simulate() public override {
        address proposerAddress = address(1);
        IERC20VotesComp governanceToken = governor.comp();
        {
            // Ensure the proposer meets the minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.quorumVotes();
            uint256 proposalThreshold = governor.proposalThreshold();
            uint256 votingPower = quorumVotes > proposalThreshold
                ? quorumVotes
                : proposalThreshold;
            deal(address(governanceToken), proposerAddress, votingPower);
            // Delegate proposer's votes to itself
            vm.prank(proposerAddress);
            IERC20VotesComp(governanceToken).delegate(proposerAddress);
            vm.roll(block.number + 1);
        }

        bytes memory proposeCalldata = getCalldata();

        // Register the proposal
        vm.prank(proposerAddress);
        bytes memory data = address(governor).functionCall(proposeCalldata);
        uint256 proposalId = abi.decode(data, (uint256));

        // Check if the proposal is in Pending state
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Pending
        );

        // Roll to Active state (voting period)
        vm.roll(block.number + governor.votingDelay() + 1);
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Active
        );

        // Vote YES
        vm.prank(proposerAddress);
        governor.castVote(proposalId, 1);

        // Roll to allow proposal state transitions
        vm.roll(block.number + governor.votingPeriod());
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Succeeded
        );

        // Queue the proposal
        governor.queue(proposalId);
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Queued
        );

        // Warp to allow proposal execution on timelock
        ITimelockBravo timelock = ITimelockBravo(governor.timelock());
        vm.warp(block.timestamp + timelock.delay());

        // Execute the proposal
        governor.execute(proposalId);
        require(
            governor.state(proposalId) == IGovernorBravo.ProposalState.Executed
        );
    }
    ```

    Without calling `build` first, the `simulate` function would be a no-op as there would be no predefined actions to execute.

-   `function validate() public`: Validates the system state post-proposal simulation. This allows checking that the contract's variables and newly deployed contracts are set up correctly and that the actions in the build were simulated correctly. In the `Proposal` contract, this function is empty.

    ```solidity
    function validate() public virtual {}
    ```

    This function is overridden at the proposal-specific contract. For example, we can take a look at the Governor Bravo `validate()` method. It checks the deployment by ensuring the total supply is 10 million and Bravo Timelock is the owner of the deployed token and vault, as the ownership of these contracts was transferred from the deployer EOA to the Bravo Timelock in the `deploy()` method for this proposal. It checks the build actions simulation by ensuring that the token was successfully whitelisted on the vault and the vault's token balance is equal to the Bravo Timelock's deposit in the vault.

    ```solidity
    function validate() public override {
        // Get vault address
        Vault bravoVault = Vault(addresses.getAddress("BRAVO_VAULT"));

        // Get token address
        Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));

        // Get Governor Bravo's Timelock address
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

        // Ensure the token total supply is 10 million
        assertEq(token.totalSupply(), 10_000_000e18);

        // Ensure the Timelock is the owner of the deployed token.
        assertEq(token.owner(), address(timelock));

        // Ensure the Timelock is the owner of the deployed vault
        assertEq(bravoVault.owner(), address(timelock));

        // Ensure the vault is not paused
        assertFalse(bravoVault.paused());

        // Ensure the token is whitelisted on the vault
        assertTrue(bravoVault.tokenWhitelist(address(token)));

        // Get the vault's token balance
        uint256 balance = token.balanceOf(address(bravoVault));

        // Get the Timelock deposits in the vault
        (uint256 amount, ) = bravoVault.deposits(
            address(token),
            address(timelock)
        );

        // Ensure the Timelock deposit is the same as the vault's token balance
        assertEq(amount, balance);

        // Ensure all minted tokens are deposited into the vault
        assertEq(token.balanceOf(address(bravoVault)), token.totalSupply());
    }
    ```

<a id="#run-function"></a>

-   `function run() public`: This function serves as the entry point for proposal execution. It selects the `primaryForkId` which will be used to run the proposal simulation. It executes `deploy()`, `afterDeployMock()`, `build()`, `simulate()`, `validate()`, and `print()` in that order if the flag for a function is set to true. `deploy()` is encapsulated in start and stop broadcast. This is done so that contracts can be deployed on-chain.

    ```solidity
    function run() public virtual {
        vm.selectFork(primaryForkId);

        if (DO_DEPLOY) {
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
    ```

    This function is overridden at the proposal-specific contract. For example, let's take a look at the Governor Bravo `run()` method. Here, this function sets the environment for proposal execution and then finally simulates the proposal by calling the `run()` of the parent `Proposal` contract. In this example, first `primaryForkId` is set to `sepolia`. Next, the `addresses` object is set by reading the `Addresses.json` file. We make the state of the `addresses` contract persist across selected fork so that we don't need to set the `addresses` object every time we `selectFork`. The Bravo governor specific contract requires setting the Bravo governor contract address as it is required in `simulate()` and `checkOnChainCalldata()` functions. Finally, `run()` sets the Bravo governor address and calls `super.run()`.

    ```solidity
    function run() public override {
        // Create and select sepolia fork for proposal execution.
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        // Set addresses object reading addresses from json file.
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("addresses/Addresses.json"))
            )
        );

        // Make 'addresses' state persist across selected fork.
        vm.makePersistent(address(addresses));

        // Set governor Bravo. This address is used for proposal simulation and check on
        // chain proposal state.
        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `function checkOnChainCalldata() public`: Check if there are any on-chain proposals that match the proposal calldata. There is no need to override this function at the proposal contract level as it is already overridden in the proposal type contract. Check [Timelock Proposal](../../../src/proposals/TimelockProposal.sol), [Governor Bravo Proposal](../../../src/proposals/GovernorBravoProposal.sol) and [Governor OZ Proposal](../../../src/proposals/GovernorOZProposal.sol) to get implementation details for each proposal tyoe.

-   `function print() public`: Print proposal description, actions, and calldata. No need to override.

<a id="#flexibility"></a>
The actions in FPS are designed to be loosely coupled for flexible implementation, with the exception of the build and simulate functions, which require sequential execution. This design choice offers developers significant flexibility and power in tailoring the system to their specific needs. For example, a developer may choose to only execute the deploy and validate functions, bypassing the others. This could be suitable in situations where only initial deployment and final validation are necessary, without the need for intermediate steps. Alternatively, a developer might opt to simulate a proposal by executing only the build and simulate functions, omitting the deploy step if there is no need to deploy new contracts. FPS empowers developers with the ability to pick and choose functions from a proposal for integration tests, deployment scripts, and governance proposal creation as it becomes easy to access whichever part of a governance proposal that is needed exactly how it will be run in production.
