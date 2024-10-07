# Governor Bravo Proposal

## Overview

Following the addition of FPS to project dependencies, the next step is creating a Proposal contract. This example serves as a guide for drafting a proposal for Governor Bravo contract.

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
        // Set Governor Bravo's timelock as the owner for the vault and token
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

-   `build()`: Add actions to the proposal contract. In this example, an ERC20 token is whitelisted on the Vault contract. Then the Governor Bravo's timelock approves the token to be spent by the vault, and calls deposit on the vault. The actions should be written in solidity code and in the order they should be executed in the proposal. Any calls (except to the Addresses and Foundry Vm contract) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`; it is the Governor Bravo's timelock for this example. The `buildModifier` is a necessary modifier for the `build` function and will not work without it. For further reading, see the [build function](../overview/architecture/proposal-functions.md#build-function).

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

-   `run()`: Sets up the environment for running the proposal. This sets `addresses`, `primaryForkId`, and `governor`, and then calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `sepolia` for executing the proposal. Next, the `addresses` object is set by reading from the addresses JSON file. The Governor Bravo contract to test is set using `setGovernor`. This will be used to check onchain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

    ```solidity
    function run() public override {
        // Create and select sepolia fork for proposal execution.
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        string memory addressesFolderPath = "./addresses";
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        // Set addresses object reading addresses from json file.
        setAddresses(
            new Addresses(addressesFolderPath, chainIds)
        );

        // Set Governor Bravo. This address is used for proposal simulation and check on
        // chain proposal state.
        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `simulate()`: For Governor Bravo proposals, this function is defined in the governance specific contract and needs not be overridden. This function executes the proposal actions outlined in the `build()` step. The following steps are run when simulating a proposal. First, the required number of governance tokens are minted to the proposer address. Second, the proposer delegates votes to himself and proposes the proposal. Then the time is skipped by the voting delay, proposer casts votes and the proposal is queued. Next, time is skipped by the timelock delay and then finally, the proposal is executed in the timelock. View the code snippet below with inline comments for an example.

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

Before running the script, add the `DEPLOYER_EOA` address to the `11155111.json` file.

```json
[
    {
        "addr": "0x<YOUR_DEV_ADDRESS>",
        "name": "DEPLOYER_EOA",
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

Copy the addresses of the timelock, governor, and governance token from the script output and add them to the `11155111.json` file. The file should follow this structure:

```json
[
    {
        "addr": "0x<YOUR_TIMELOCK_ADDRESS>",
        "name": "PROTOCOL_TIMELOCK",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_GOVERNOR_ADDRESS>",
        "name": "GOVERNOR_BRAVO",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_GOVERNANCE_TOKEN_ADDRESS>",
        "isContract": true,
        "name": "PROTOCOL_GOVERNANCE_TOKEN"
    },
    {
        "addr": "0x<YOUR_DEV_ADDRESS>",
        "name": "DEPLOYER_EOA",
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

Copy the `GOVERNOR_BRAVO_ALPHA` address from the script output and add it to the `11155111.json` file. The final `11155111.json` file should follow this structure:

```json
[
    {
        "addr": "0x<YOUR_TIMELOCK_ADDRESS>",
        "name": "PROTOCOL_TIMELOCK",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_GOVERNOR_ADDRESS>",
        "name": "GOVERNOR_BRAVO",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_GOVERNANCE_TOKEN_ADDRESS>",
        "isContract": true,
        "name": "PROTOCOL_GOVERNANCE_TOKEN"
    },
    {
        "addr": "0x<YOUR_GOVERNOR_ALPHA_ADDRESS>",
        "name": "GOVERNOR_BRAVO_ALPHA",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_DEV_ADDRESS>",
        "name": "DEPLOYER_EOA",
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
          "addr": "0x69A5DfCD97eF074108b480e369CecfD9335565A2",
          "isContract": true,
          "name": "BRAVO_VAULT"
},
  {
          "addr": "0x541234b61c081eaAE62c9EF52A633cD2aaf92A05",
          "isContract": true,
          "name": "BRAVO_VAULT_TOKEN"
}

---------------- Proposal Description ----------------
  Bravo proposal mock

------------------ Proposal Actions ------------------
  1). calling BRAVO_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001 data.
  target: BRAVO_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001


  2). calling BRAVO_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 with 0 eth and 0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000 data.
  target: BRAVO_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05
payload
  0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000


  3). calling BRAVO_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000 data.
  target: BRAVO_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000



----------------- Proposal Changes ---------------


 BRAVO_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2:

 State Changes:
  Slot: 0x0109a4c58357d68655b3b5dc2118952a94bd8ac20af5042c287646f3faf63d0e
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000000000001
  Slot: 0x03f62bda81ef166f1cb51858c0b52c0203caebd9f546b6321f329143160571e6
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0x03f62bda81ef166f1cb51858c0b52c0203caebd9f546b6321f329143160571e7
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000066b3625c


 BRAVO_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05:

 State Changes:
  Slot: 0x9e8d6b450a8ff102c29486d666c519809e451e279af63f2f116c2c6d3c42003e
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0x9e8d6b450a8ff102c29486d666c519809e451e279af63f2f116c2c6d3c42003e
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0x367d8f8d08b068e2c4f2b565d1cf8f08fb278cf5b23a25b874071c824aa6f466
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0xdbde422d34765d6fa450f050d95a7072ade5d1938cc2a6df4441c92d8c263663
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000


 PROTOCOL_TIMELOCK_BRAVO @0xF75C465c091bDcb9D28A767AaC44d4aAFa4b7Af1:

 Transfers:
  Sent 10000000000000000000000000 BRAVO_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 to BRAVO_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2


------------------ Proposal Calldata ------------------
  0xda95691a00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000480000000000000000000000000000000000000000000000000000000000000000300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a0500000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000013427261766f2070726f706f73616c206d6f636b00000000000000000000000000
```

A DAO member can verify whether the calldata proposed on the governance matches the calldata from the script execution. It is crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON files when proposal is run without the `DO_UPDATE_ADDRESS_JSON` flag set to true.

The proposal script will deploy the contracts in the `deploy()` method and will generate actions calldata for each individual action along with proposal calldata for the proposal. The proposal can be manually proposed using `cast send` along with the calldata generated above.
