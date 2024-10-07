# OZ Governor Proposal

## Overview

Following the addition of FPS to project dependencies, the next step is creating a Proposal contract. This example serves as a guide for drafting a proposal for OZ Governor contract.

## Proposal Contract

The `OZGovernorProposal_01` proposal is available in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-governor-oz/OZGovernorProposal_01.sol). This contract is used as a reference for this tutorial.

Let's go through each of the overridden functions.

-   `name()`: Define the name of your proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "OZ_GOVERNOR_PROPOSAL";
    }
    ```

-   `description()`: Provide a detailed description of your proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return "OZ Governor proposal mock 1";
    }
    ```

-   `deploy()`: Deploy any necessary contracts. This example demonstrates the deployment of Vault and an ERC20 token. Once the contracts are deployed, they are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // Set OZ Governor's timelock as the owner for vault and token.
        address owner = addresses.getAddress("OZ_GOVERNOR_TIMELOCK");

        // Deploy vault address if not already deployed and transfer ownership to timelock.
        if (!addresses.isAddressSet("OZ_GOVERNOR_VAULT")) {
            Vault OZGovernorVault = new Vault();

            addresses.addAddress(
                "OZ_GOVERNOR_VAULT",
                address(OZGovernorVault),
                true
            );
            OZGovernorVault.transferOwnership(owner);
        }

        // Deploy token address if not already deployed, transfer ownership to timelock
        // and transfer all initial minted tokens from the deployer to the timelock.
        if (!addresses.isAddressSet("OZ_GOVERNOR_VAULT_TOKEN")) {
            Token token = new Token();
            addresses.addAddress(
                "OZ_GOVERNOR_VAULT_TOKEN",
                address(token),
                true
            );
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

-   `build()`: Add actions to the proposal contract. In this example, an ERC20 token is whitelisted on the Vault contract. Then the OZ Governor's timelock approves the token to be spent by the vault, and calls deposit on the vault. The actions should be written in solidity code and in the order they should be executed in the proposal. Any calls (except to the Addresses and Foundry Vm contract) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`; it is the OZ Governor's timelock for this example. The `buildModifier` is a necessary modifier for the `build` function and will not work without it. For further reading, see the [build function](../overview/architecture/proposal-functions.md#build-function).

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("OZ_GOVERNOR_TIMELOCK"))
    {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get vault address
        address OZGovernorVault = addresses.getAddress("OZ_GOVERNOR_VAULT");

        // Get token address
        address token = addresses.getAddress("OZ_GOVERNOR_VAULT_TOKEN");

        // Get OZ Governor timelock's token balance.
        uint256 balance = Token(token).balanceOf(
            addresses.getAddress("OZ_GOVERNOR_TIMELOCK")
        );

        /// CALLS -- mutative and recorded

        // Whitelists the deployed token on the deployed vault.
        Vault(OZGovernorVault).whitelistToken(token, true);

        // Approve the token for the vault.
        Token(token).approve(OZGovernorVault, balance);

        // Deposit all tokens into the vault.
        Vault(OZGovernorVault).deposit(token, balance);
    }
    ```

-   `run()`: Sets up the environment for running the proposal, and executes all proposal actions. This sets `addresses`, `primaryForkId`, and `governor` and calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `sepolia` and selecting the fork for running the proposal. Next, the `addresses` object is set by reading from the JSON file. The OZ Governor contract to test is set using `setGovernor`. This will be used to check onchain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

    ```solidity
    function run() public override {
        // Create and select the sepolia fork for proposal execution.
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        string memory addressesFolderPath = "./addresses";
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        // Set the addresses object by reading addresses from the json file.
        setAddresses(
            new Addresses(addressesFolderPath, chainIds)
        );

        // Set OZ Governor. This address is used for proposal simulation and checking on-chain proposal state.
        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

        // Call the run function of the parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `simulate()`: For OZ Governor proposal, this function is defined in the governance specific contract and needs not to be overridden. This function executes the proposal actions outlined in the `build()` step. First required number of governance tokens are minted to the proposer address. Proposer delegates votes to himself and then proposes the proposal. Then the time is skipped by the voting delay, proposer casts vote and the proposal is queued. Next, time is skipped by the timelock delay and then finally the proposal is executed. Check the code snippet below with inline comments to get a better idea.

    ```solidity
    /// @notice Simulate governance proposal
    function simulate() public virtual override {
        address proposerAddress = address(1);
        IVotes governanceToken = IVotes(
            IGovernorVotes(address(governor)).token()
        );
        {
            // Ensure proposer has meets minimum proposal threshold and quorum votes to pass the proposal
            uint256 quorumVotes = governor.quorum(block.number - 1);
            uint256 proposalThreshold = governor.proposalThreshold();
            uint256 votingPower = quorumVotes > proposalThreshold
                ? quorumVotes
                : proposalThreshold;
            deal(address(governanceToken), proposerAddress, votingPower);
            vm.roll(block.number - 1);
            // Delegate proposer's votes to itself
            vm.prank(proposerAddress);
            IVotes(governanceToken).delegate(proposerAddress);
            vm.roll(block.number + 2);
        }

        bytes memory proposeCalldata = getCalldata();

        // Register the proposal
        vm.prank(proposerAddress);
        bytes memory data = address(governor).functionCall(proposeCalldata);

        uint256 returnedProposalId = abi.decode(data, (uint256));

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = getProposalActions();

        // Check that the proposal was registered correctly
        uint256 proposalId = governor.hashProposal(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(description()))
        );

        require(returnedProposalId == proposalId, "Proposal id mismatch");

        // Check proposal is in Pending state
        require(governor.state(proposalId) == IGovernor.ProposalState.Pending);

        // Roll to Active state (voting period)
        vm.roll(block.number + governor.votingDelay() + 1);

        require(governor.state(proposalId) == IGovernor.ProposalState.Active);

        // Vote YES
        vm.prank(proposerAddress);
        governor.castVote(proposalId, 1);

        // Roll to allow proposal state transitions
        vm.roll(block.number + governor.votingPeriod());

        require(
            governor.state(proposalId) == IGovernor.ProposalState.Succeeded
        );

        vm.warp(block.timestamp + governor.proposalEta(proposalId) + 1);

        // Queue the proposal
        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(description()))
        );

        require(governor.state(proposalId) == IGovernor.ProposalState.Queued);

        // Warp to allow proposal execution on timelock
        ITimelockController timelock = ITimelockController(
            IGovernorTimelockControl(address(governor)).timelock()
        );
        vm.warp(block.timestamp + timelock.getMinDelay());

        // Execute the proposal
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(description()))
        );

        require(governor.state(proposalId) == IGovernor.ProposalState.Executed);
    }
    ```

-   `validate()`: This final step validates the system in its post-execution state. It ensures that the OZ Governor's timelock is the new owner of the Vault and token, the tokens were transferred to OZ Governor's timelock, and the token was whitelisted on the Vault contract.

    ```solidity
    function validate() public override {
        // Get the vault address
        Vault OZGovernorVault = Vault(
            addresses.getAddress("OZ_GOVERNOR_VAULT")
        );

        // Get the token address
        Token token = Token(addresses.getAddress("OZ_GOVERNOR_VAULT_TOKEN"));

        // Get OZ Governor's timelock address
        address timelock = addresses.getAddress("OZ_GOVERNOR_TIMELOCK");

        // Ensure the token total supply is 10 million
        assertEq(token.totalSupply(), 10_000_000e18);

        // Ensure the timelock is the owner of the deployed token.
        assertEq(token.owner(), address(timelock));

        // Ensure the timelock is the owner of the deployed vault
        assertEq(OZGovernorVault.owner(), address(timelock));

        // Ensure the vault is not paused
        assertFalse(OZGovernorVault.paused());

        // Ensure the token is whitelisted on the vault
        assertTrue(OZGovernorVault.tokenWhitelist(address(token)));

        // Get the vault's token balance
        uint256 balance = token.balanceOf(address(OZGovernorVault));

        // Get the timelock deposits in the vault
        (uint256 amount, ) = OZGovernorVault.deposits(
            address(token),
            address(timelock)
        );

        // Ensure the timelock deposit is the same as the vault's token balance
        assertEq(amount, balance);

        // Ensure all minted tokens are deposited into the vault
        assertEq(
            token.balanceOf(address(OZGovernorVault)),
            token.totalSupply()
        );
    }
    ```

## Proposal Simulation

### Deploying a OZ Governor on Testnet

A OZ Governor contract is needed to be set up on the testnet before running the proposal.

This script [DeployOZGovernor](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script/DeployOZGovernor.s.sol) facilitates this process.

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

After adding the address, run the script:

```sh
forge script script/DeployOZGovernor.s.sol --rpc-url sepolia --broadcast
-vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/`.

### Setting Up the Addresses JSON

Copy the addresses of the timelock, governor, and governance token from the script output and add them to the `11155111.json` file. The file should follow this structure:

```json
[
    {
        "addr": "0x<YOUR_TIMELOCK_ADDRESS>",
        "name": "OZ_GOVERNOR_TIMELOCK",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_GOVERNOR_ADDRESS>",
        "name": "OZ_GOVERNOR",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_GOVERNANCE_TOKEN_ADDRESS>",
        "isContract": true,
        "name": "OZ_GOVERNOR_GOVERNANCE_TOKEN"
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
forge script src/proposals/simple-vault-governor-oz/OZGovernorProposal_01.sol --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          "addr": "0x69A5DfCD97eF074108b480e369CecfD9335565A2",
          "isContract": true,
          "name": "OZ_GOVERNOR_VAULT"
},
  {
          "addr": "0x541234b61c081eaAE62c9EF52A633cD2aaf92A05",
          "isContract": true,
          "name": "OZ_GOVERNOR_VAULT_TOKEN"
}

---------------- Proposal Description ----------------
  OZ Governor proposal mock 1

------------------ Proposal Actions ------------------
  1). calling OZ_GOVERNOR_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001 data.
  target: OZ_GOVERNOR_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001


  2). calling OZ_GOVERNOR_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 with 0 eth and 0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000 data.
  target: OZ_GOVERNOR_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05
payload
  0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000


  3). calling OZ_GOVERNOR_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000 data.
  target: OZ_GOVERNOR_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000



----------------- Proposal Changes ---------------


 OZ_GOVERNOR_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2:

 State Changes:
  Slot: 0x0109a4c58357d68655b3b5dc2118952a94bd8ac20af5042c287646f3faf63d0e
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000000000001
  Slot: 0xd6aeaeb3300a8de8546c3164db6c6689eaa6df771a85348358817727e885046e
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0xd6aeaeb3300a8de8546c3164db6c6689eaa6df771a85348358817727e885046f
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000066b36484


 OZ_GOVERNOR_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05:

 State Changes:
  Slot: 0xf51fdc8c89661be75f898df18c3da3a5aab2536504db7216e2b7d817bb1d0b7c
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0xf51fdc8c89661be75f898df18c3da3a5aab2536504db7216e2b7d817bb1d0b7c
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0xabf7c1bc82cf6c53ee2adf60845603e0c903e8d02c0d5cfbbd892c2611073b21
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0xdbde422d34765d6fa450f050d95a7072ade5d1938cc2a6df4441c92d8c263663
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000


 OZ_GOVERNOR_TIMELOCK @0xD21a3b1b572F7C38b5e3ff841d1D2903e1B03695:

 Transfers:
  Sent 10000000000000000000000000 OZ_GOVERNOR_VAULT_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 to OZ_GOVERNOR_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2


------------------ Proposal Calldata ------------------
  0x7d5e81e20000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000000300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a0500000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b4f5a20476f7665726e6f722070726f706f73616c206d6f636b20310000000000
```

A DAO member can check whether the calldata proposed on the governance matches the calldata from the script exeuction. It is crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON files when proposal is run without the `DO_UPDATE_ADDRESS_JSON` flag set to true.

The proposal script will deploy the contracts in `deploy()` method and will generate actions calldata for each individual action along with proposal calldata for the proposal. The proposal can be proposed manually using `cast send` along with the calldata generated above.
