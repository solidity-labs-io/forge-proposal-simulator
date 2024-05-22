The [Proposal.sol](../../../src/proposals/Proposal.sol) file contains a set of functions that all governance models inherit. There are currently four governance models inheriting from Proposal.sol: Bravo, Multisig, Timelock and OpenZeppelin Governor. When using FPS for any of the abovementioned models for creating proposals, all that needs to be done is to inherit one of the proposal types, such as [GovernorBravoProposal.sol](../../../src/proposals/GovernorBravoProposal.sol) and override the necessary functions to create the proposal, like `build` and `deploy`. FPS is flexible enough so that for any different governance model, governance proposal types can be easily adjusted to fit into the governance architecture. An example has been provided using Arbitrum Governance on FPS example repo (link here) to demonstrate FPS flexibility. The following is a list of functions proposals can implement:

-   `function name() public`: This is an empty function in `Proposal` contract.

    ```solidity
    function name() external view virtual returns (string memory);
    ```

    Override this function in the proposal specific contract to define the proposal name. Example:

    ```solidity
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }
    ```

-   `function description() public`: This is an empty function in `Proposal` contract.

    ```solidity
    function description() public view virtual returns (string memory);
    ```

    Override this function in the proposal specific contract to define the proposal description. Example:

    ```solidity
    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
    }
    ```

-   `function deploy() public`: This is an empty function in `Proposal` contract.

    ```solidity
    function deploy() public virtual {}
    ```

    Override this function when there are deployments to be made in the proposal. Here is an example from a [governor bravo proposal](../../guides/governor-bravo-proposal.md). Here two contracts are deployed, Vault and Token if they are not already deployed.

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

    Deployments are done by `DEPLOYER_EOA` address defined in `Addresses.json`. We get this address while setting the proposal environment in the `run` function, please refer `run` function documentation below to get more details. In tests `deploy()` is used to simulates the proposal contract deployments and on the other hand when the proposal is run as a script with broadcast flag and deployer eoa private key, it is used to deploy all the contracts on chain and adds those addresses to the `addresses` object.

-   `function afterDeployMock() public`: Post-deployment mock actions. Such actions can include pranking, etching, etc.

<a id="#build-function"></a>

-   `function build() public`: Besides deployments a proposal will have some actions to be made, for eg: transferring of ownership rights of a deployed contract. This function helps create and store these actions, each of these actions stores a target contract and calldata for making that action. In Proposal contract it is an empty function. This function should always be overridden in the proposal specific contract as every proposal must have atleast a single action to be made.

    ```solidity
    function build() public virtual {}
    ```

    This function helps the user store the actions without having to write any complicated calldata generation code by cleverly using a few foundry features. This can be best understood by having a look at the `buildModifier` in the `Proposal` contract. This modifier runs `_startBuild()` function before `build()` and `endBuild()` function after `build()`. `toPrank` is also passed as a parameter to this modifier which is the address that will be used as the caller for the actions in the proposal, eg: multisig address, timelock address, etc. In `startBuild()` function first of all we prank to the caller address and then take a snapshot of the start state by using foundry's `vm.snapshot()` feature. After this we call foundry's `vm.startStateDiffRecording()` which will now start recording all the function calls made after this step. Next the `build()` function will run and all the steps in the build will be recorded. Finally `endBuild()` will run, first it will stop the state diff recording and get all the calls info, then stop prank, then revert the state to the start snapshot and finally it will filter the calls made by the caller and also ignore the static calls. This way only the mutative calls made by the caller will be filtered out and these calls are finally stored in the actions array. Inside end build duplicate actions are also checked using `_validateAction` and custom checks can also be created using `_validateActions` like target should always be timelock contract, value should always be 0 or any custom action check.

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

            _validateActions();
        }
    }
    ```

    For more clear understanding we can have a look at the bravo proposal example snippet. Here `build()` has the `buildModifier` which takes `PROTOCOL_TIMELOCK_BRAVO` as the caller. Multiple calls are made in the `build()` function but only the mutative calls made by the caller will be stored in the actions array. In this example there are three mutative actions. First, deployed token is whitelisted on the deployed vault. Second, vault is approved to transfer some `balance` on behalf of bravo timelock contract. Third, `balance` amount of tokens are deposited in the vault from the bravo timelock contract.

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

        // Get timelock bravo's token balance.
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

-   `function getProposalActions() public`: Retrieves the sequence of actions for a proposal. This function should not be overridden in most of the cases.

-   `function getCalldata() public`: Retrieves any generated governance proposal calldata. TainCalldata() public`: Check if any on-chain proposal matches the proposal calldata. There is no need to override this function at the proposal contract level as it is already overridden in the proposal type contract.

-   `function simulate() public`: Executes the previously saved actions during the `build` step. This function's execution is dependent on the successful execution of the `build` function. On Proposal contract this function is empty.

    ```solidity
    function simulate() public virtual {}
    ```

    This function can we overridden at the governance specific contract or the proposal specific contract depending on the type of proposal. For eg: governor bravo type overrides this function at the governance specific contract while timelock type overrides at the proposal specific contract. Here we will take a look at the governor bravo type example. In this example we have a proposer address that proposes the proposal to the governance contract. It first transfers and delegates governance tokens that meet the minimum proposal threshold and quorum votes to itself, then it registers the proposal, then it rolls the proposal to the Active state so that voting can begin, then it votes yes to the proposal, then it rolls to block where voting period has ended and now the proposal is in Succeeded state, then it queue the proposal in the governance timelock contract, then it warps to the end of timelock delay period and finally executes the proposal, thus simulating the complete proposal on the local fork.

    ```solidity
    function simulate() public override {
        address proposerAddress = address(1);
        IERC20VotesComp governanceToken = governor.comp();
        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
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

        // Check proposal is in Pending state
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

    Without calling `build` first, `simulate` function becomes ineffectual as there would be no predefined actions to execute.

-   `function validate() public`: Validates system state post proposal simulation. This allows checking that contract's variables and newly deployed contracts are set up correctly and the actions in the build were simulated correctly. In `Proposal` contract this function is empty.

        ```solidity
        function validate() public virtual {}
        ```

        This function is overridden at the proposal specefic contract. For eg: we can have a look at governor bravo `validate()` method. It checks the deployment by ensuring the total supply is 10 million and bravo timelock is the owner of deployed token and vault as the ownersip of these contracts was transferred from deployer eoa to the bravo timelock in the `deploy()` method for this proposal. It checks the build actions simulation by ensuring that token was successfully whitelisted on the vault and the vault's token balance is equal to the bravo timelock's deposit in the vault.

        ```solidity
        function validate() public override {
            // Get vault address
            Vault bravoVault = Vault(addresses.getAddress("BRAVO_VAULT"));

            // Get token address
            Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));

            // Get governor bravo's timelock address
            address timelock = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

            // Ensure token total supply is 10 million
            assertEq(token.totalSupply(), 10_000_000e18);

            // Ensure timelock is owner of deployed token.
            assertEq(token.owner(), address(timelock));

            // Ensure timelock is owner of deployed vault
            assertEq(bravoVault.owner(), address(timelock));

            // Ensure vault is not paused
            assertFalse(bravoVault.paused());

            // Ensure token is whitelisted on vault
            assertTrue(bravoVault.tokenWhitelist(address(token)));

            // Get vault's token balance
            uint256 balance = token.balanceOf(address(bravoVault));

            // Get timelock deposits in vault
            (uint256 amount, ) = bravoVault.deposits(
                address(token),
                address(timelock)
            );

            // Ensure timelock deposit is same as vault's token balance
            assertEq(amount, balance);

            // Ensure all minted tokens are deposited into the vault
            assertEq(token.balanceOf(address(bravoVault)), token.totalSupply());
        }
        ```

    <a id="#run-function"></a>

-   `function run() public`: This function serves as the entry point for proposal execution. It selects the `primaryForkId` which will be used to run the proposal simulation. It executes `deploy()`, `afterDeployMock()`, `build()`, `simulate()`, `validate()` and `print()` in that order if the flag for a function is set to true. `deploy()` is encapsulated in start and stop broadcast, this is done so that contracts can be deployed on chain.

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

    This function is overridden at the proposal specific contract. For eg: let's take a look at the governor bravo `run()` method. Here this function sets the environment for proposal execution and then finally simulates the proposal by calling the `run()` of the parent `Proposal` contract. In this example first `primaryForkId` is set to `sepolia`. Next `addresses` object is set by reading the `Addresses.json` file. We make the state of the `addresses` contract persist across selected fork so that we don't need to set `addresses` object every time we selectFork. The bravo governor specific contract requires to set the bravo governor contract address as it requires this address in `simulate()` and `checkOnChainCalldata()` functions. Finally `run()` sets the bravo governor address and calls `super.run()`.

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

        // Set governor bravo. This address is used for proposal simulation and check on
        // chain proposal state.
        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `function checkOnChainCalldata() public`: Check if there are any on-chain proposal that matches the proposal calldata. There is no need to override this function at the proposal contract level as it is already overridden in the proposal type contract. [Timelock Proposal](../../../src/proposals/TimelockProposal.sol), [Governor Bravo Proposal](../../../src/proposals/GovernorBravoProposal.sol)

-   `function print() public`: Print proposal description, actions and calldata. No need to override.

The actions in FPS are designed to be loosely coupled for flexible implementation, with the exception of the build and run functions, which require sequential execution. This design choice offers developers significant flexibility and power in tailoring the system to their specific needs. For example, a developer may choose to only execute the deploy and validate functions, bypassing the others. This could be suitable in situations where only initial deployment and final validation are necessary, without the need for intermediate steps. Alternatively, a developer might opt to simulate a proposal by executing only the build and run functions, omitting the deploy step if there is no need to deploy new contracts. FPS empowers developers with the ability to pick and choose speeds integration tests, deployment scripts, and governance proposal creation as it becomes easy to access whichever part of a governance proposal that is needed.
