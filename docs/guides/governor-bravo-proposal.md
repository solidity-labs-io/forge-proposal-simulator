# Governor Bravo Proposal

## Overview

Following the addition of FPS to project dependencies, the subsequent step involves creating the initial Proposal contract. This example serves as a guide for drafting a proposal for Governor Bravo contract.

## Proposal Contract

The `BravoProposal_01` proposal is available in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-bravo/BravoProposal_01.sol). This contract is used as a reference for this tutorial.

Let's go through each of the overridden functions.

-   `name()`: Defines the name of your proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }
    ```

-   `description()`: Provides a detailed description of your proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
    }
    ```

-   `deploy()`: Deploys any necessary contracts. This example demonstrates the deployment of Vault and an ERC20 token. Once deployed, these contracts are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // Set governor bravo's timelock as the owner for the vault and token
        address owner = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

        // Deploy the vault address if not already deployed and transfer ownership to the timelock
        if (!addresses.isAddressSet("BRAVO_VAULT")) {
            Vault bravoVault = new Vault();

            addresses.addAddress("BRAVO_VAULT", address(bravoVault), true);
            bravoVault.transferOwnership(owner);
        }

        // Deploy the token address if not already deployed, transfer ownership to the timelock
        // and transfer all initial minted tokens from the deployer to the timelock
        if (!addresses.isAddressSet("BRAVO_VAULT_TOKEN")) {
            Token token = new Token();
            addresses.addAddress("BRAVO_VAULT_TOKEN", address(token), true);
            token.transferOwnership(owner);

            // During forge script execution, the deployer of the contracts is
            // the DEPLOYER_EOA. However, when running through forge test, the deployer of the contracts is this contract.
            uint256 balance = token.balanceOf(address(this)) > 0
                ? token.balanceOf(address(this))
                : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));

            token.transfer(address(owner), balance);
        }
    }
    ```

    Since these changes do not persist from runs themselves, after the contracts are deployed, the user must update the Addresses.json file with the newly deployed contract addresses.

-   `build()`: Add actions to the proposal contract. [See build function](../overview/architecture/proposal-functions.md#build-function). In this example, an ERC20 token is whitelisted on the Vault contract. Then, the timelock approves the token for the vault and deposits all tokens into the vault. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`; it is the Governor bravo's timelock for this example. `buildModifier` is a necessary modifier for the `build` function and will not work without it.

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO"))
    {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get the vault address
        address bravoVault = addresses.getAddress("BRAVO_VAULT");

        // Get the token address
        address token = addresses.getAddress("BRAVO_VAULT_TOKEN");

        // Get the timelock bravo's token balance
        uint256 balance = Token(token).balanceOf(
            addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO")
        );

        /// CALLS -- mutative and recorded

        // Whitelist the deployed token on the deployed vault
        Vault(bravoVault).whitelistToken(token, true);

        // Approve the token for the vault
        Token(token).approve(bravoVault, balance);

        // Deposit all tokens into the vault
        Vault(bravoVault).deposit(token, balance);
    }
    ```

-   `run()`: Sets up the environment for running the proposal. [See run function](../overview/architecture/proposal-functions.md#run-function). This sets `addresses`, `primaryForkId`, and `governor`, and then calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `sepolia` for executing the proposal. Next, the `addresses` object is set by reading from the `addresses.json` file. The Governor bravo address to simulate the proposal through is set using `setGovernor`. This will be used to check onchain calldata and simulate the proposal.

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

        // Set governor bravo. This address is used for proposal simulation and check on
        // chain proposal state.
        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `simulate()`: For governor bravo proposal, this function is defined in the governance specific contract and needs not to be overridden. This function executes the proposal actions outlined in the `build()` step. First required number of governance tokens are minted to the proposer address. Proposer delegates votes to himself and then proposes the proposal. Then the time is skipped by the voting delay, proposer casts vote and the proposal is queued. Next, time is skipped by the timelock delay and then finally the proposal is executed. Check the code snippet below with inline comments to get a better idea.

    ```solidity
    /// @notice Simulate governance proposal
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

-   `validate()`: This final step validates the system in its post-execution state. It ensures that Governor Bravo's timelock is the new owner of the Vault and token, the tokens were transferred to Governor Bravo's timelock, and the token was whitelisted on the Vault contract.

    ```solidity
    function validate() public override {
        // Get the vault address
        Vault bravoVault = Vault(addresses.getAddress("BRAVO_VAULT"));

        // Get the token address
        Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));

        // Get Governor Bravo's timelock address
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

        // Ensure the token total supply is 10 million
        assertEq(token.totalSupply(), 10_000_000e18);

        // Ensure the timelock is the owner of the deployed token
        assertEq(token.owner(), address(timelock));

        // Ensure the timelock is the owner of the deployed vault
        assertEq(bravoVault.owner(), address(timelock));

        // Ensure the vault is not paused
        assertFalse(bravoVault.paused());

        // Ensure the token is whitelisted on the vault
        assertTrue(bravoVault.tokenWhitelist(address(token)));

        // Get the vault's token balance
        uint256 balance = token.balanceOf(address(bravoVault));

        // Get the timelock deposits in the vault
        (uint256 amount, ) = bravoVault.deposits(
            address(token),
            address(timelock)
        );

        // Ensure the timelock deposit is the same as the vault's token balance
        assertEq(amount, balance);

        // Ensure all minted tokens are deposited into the vault
        assertEq(token.balanceOf(address(bravoVault)), token.totalSupply());
    }
    ```

## Proposal Simulation

### Deploying a Governor Bravo on Testnet

A Governor Bravo contract is needed to be set up on the testnet before running the proposal.

This script [DeployGovernorBravo](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script/DeployGovernorBravo.s.sol) facilitates this process.

Before running the script, add the `DEPLOYER_EOA` address to the `Addresses.json` file.

```json
[
    {
        "addr": "YOUR_DEV_ADDRESS",
        "name": "DEPLOYER_EOA",
        "chainId": 11155111,
        "isContract": false
    }
]
```

After adding the address, execute the script:

```sh
forge script script/DeployGovernorBravo.s.sol --rpc-url sepolia --broadcast
-vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/`.

Copy the addresses of the timelock, governor, and governance token from the script output and add them to the `Addresses.json` file. The file should look like this:

```json
[
    {
        "addr": "YOUR_TIMELOCK_ADDRESS",
        "name": "PROTOCOL_TIMELOCK",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_GOVERNOR_ADDRESS",
        "name": "GOVERNOR_BRAVO",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_GOVERNANCE_TOKEN_ADDRESS",
        "chainId": 11155111,
        "isContract": true,
        "name": "PROTOCOL_GOVERNANCE_TOKEN"
    },
    {
        "addr": "YOUR_DEV_ADDRESS",
        "name": "DEPLOYER_EOA",
        "chainId": 11155111,
        "isContract": false
    }
]
```

After adding the addresses, run the second script to accept ownership of the timelock and initialize the governor. The script to facilate this process is [InitializeBravo](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script/InitializeBravo.s.sol).
Before running the script, obtain the eta from the queue transaction on the previous script and set it as an environment variable.

```sh
export ETA=123456
```

Run the script:

```sh
forge script script/InitializeBravo.s.sol --rpc-url sepolia --broadcast -vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

### Setting Up the Addresses JSON

Copy the `GOVERNOR_BRAVO_ALPHA` address from the script output and add it to the `Addresses.json` file. The final `Addresses.json` file should be something like this:

```json
[
    {
        "addr": "YOUR_TIMELOCK_ADDRESS",
        "name": "PROTOCOL_TIMELOCK",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_GOVERNOR_ADDRESS",
        "name": "GOVERNOR_BRAVO",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_GOVERNANCE_TOKEN_ADDRESS",
        "chainId": 11155111,
        "isContract": true,
        "name": "PROTOCOL_GOVERNANCE_TOKEN"
    },
    {
        "addr": "YOUR_GOVERNOR_ALPHA_ADDRESS",
        "name": "GOVERNOR_BRAVO_ALPHA",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_DEV_ADDRESS",
        "name": "DEPLOYER_EOA",
        "chainId": 11155111,
        "isContract": false
    }
]
```

### Running the Proposal

```sh
forge script src/proposals/simple-vault-bravo/BravoProposal_01.sol --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          'addr': '0xF9C26968C2d4E1C2ADA13c6323be31c1067EBB7c',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'BRAVO_VAULT'
},
  {
          'addr': '0x2A2A18A71d0eA4B97ebb18D3820cd3625C3A1465',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'BRAVO_VAULT_TOKEN'
}

---------------- Proposal Description ----------------
  Bravo proposal mock

------------------ Proposal Actions ------------------
  1). calling 0xF9C26968C2d4E1C2ADA13c6323be31c1067EBB7c with 0 eth and 0x0ffb1d8b0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a14650000000000000000000000000000000000000000000000000000000000000001 data.
  target: 0xF9C26968C2d4E1C2ADA13c6323be31c1067EBB7c
payload
  0x0ffb1d8b0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a14650000000000000000000000000000000000000000000000000000000000000001


  2). calling 0x2A2A18A71d0eA4B97ebb18D3820cd3625C3A1465 with 0 eth and 0x095ea7b3000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000084595161401484a000000 data.
  target: 0x2A2A18A71d0eA4B97ebb18D3820cd3625C3A1465
payload
  0x095ea7b3000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000084595161401484a000000


  3). calling 0xF9C26968C2d4E1C2ADA13c6323be31c1067EBB7c with 0 eth and 0x47e7ef240000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000000000000000000000084595161401484a000000 data.
  target: 0xF9C26968C2d4E1C2ADA13c6323be31c1067EBB7c
payload
  0x47e7ef240000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000000000000000000000084595161401484a000000




------------------ Proposal Calldata ------------------
  0xda95691a00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000028000000000000000000000000000000000000000000000000000000000000004800000000000000000000000000000000000000000000000000000000000000003000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a14650000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef240000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000000000000000000000084595161401484a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013427261766f2070726f706f73616c206d6f636b00000000000000000000000000

```

A DAO member can verify whether the calldata proposed on the governance matches the calldata from the script execution. It's crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually as new contracts have now been added to the system.

The proposal script will deploy the contracts in the `deploy()` method and will generate actions calldata for each individual action along with proposal calldata for the proposal. The proposal can be manually proposed using the cast send along with the calldata generated above.
