# Governor OZ Proposal

## Overview

After adding FPS to project dependencies, the next step is creating the first Proposal contract. This example guides you in writing a proposal for deploying new instances of `Vault.sol` and `Token`. These contracts are located in the fps-example-repo [mocks](https://github.com/solidity-labs-io/fps-example-repo/tree/main/src/mocks). Copy each file in this tutorial into your project, or clone the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/) repo. This tutorial assumes you have cloned the fps-example-repo.

This proposal involves transferring ownership of both contracts to Governor OZ's timelock, along with whitelisting the token, minting tokens to the timelock, and having the timelock deposit tokens into the vault.

## Proposal Contract

Here we are using the GovernorOZProposal_01 proposal present in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-governor-oz/GovernorOZProposal_01.sol). We will use this contract as a reference for the tutorial.

Let's go through each of the overridden functions.

-   `name()`: Define the name of your proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "GOVERNOR_OZ_PROPOSAL";
    }
    ```

-   `description()`: Provide a detailed description of your proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return "Governor oz proposal mock 1";
    }
    ```

-   `deploy()`: Deploy any necessary contracts. This example demonstrates the deployment of Vault and an ERC20 token. Once the contracts are deployed, they are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // Set Governor oz's timelock as the owner for vault and token.
        address owner = addresses.getAddress("GOVERNOR_OZ_TIMELOCK");

        // Deploy vault address if not already deployed and transfer ownership to timelock.
        if (!addresses.isAddressSet("GOVERNOR_OZ_VAULT")) {
            Vault governorOZVault = new Vault();

            addresses.addAddress(
                "GOVERNOR_OZ_VAULT",
                address(governorOZVault),
                true
            );
            governorOZVault.transferOwnership(owner);
        }

        // Deploy token address if not already deployed, transfer ownership to timelock
        // and transfer all initial minted tokens from the deployer to the timelock.
        if (!addresses.isAddressSet("GOVERNOR_OZ_VAULT_TOKEN")) {
            Token token = new Token();
            addresses.addAddress(
                "GOVERNOR_OZ_VAULT_TOKEN",
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

-   `build()`: Set the necessary actions for your proposal, [Refer](../overview/architecture/proposal-functions.md#build-function) for a detailed explanation. In this example, ERC20 token is whitelisted on the Vault contract. Then, the Governor oz timelock approves the token for the vault and deposits all tokens into the vault. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address that will call actions is passed into `buildModifier`; it is the Governor oz's timelock for this example. `buildModifier` is a necessary modifier for the `build` function and will not work without it.

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("GOVERNOR_OZ_TIMELOCK"))
    {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get vault address
        address governorOZVault = addresses.getAddress("GOVERNOR_OZ_VAULT");

        // Get token address
        address token = addresses.getAddress("GOVERNOR_OZ_VAULT_TOKEN");

        // Get Governor oz timelock's token balance.
        uint256 balance = Token(token).balanceOf(
            addresses.getAddress("GOVERNOR_OZ_TIMELOCK")
        );

        /// CALLS -- mutative and recorded

        // Whitelists the deployed token on the deployed vault.
        Vault(governorOZVault).whitelistToken(token, true);

        // Approve the token for the vault.
        Token(token).approve(governorOZVault, balance);

        // Deposit all tokens into the vault.
        Vault(governorOZVault).deposit(token, balance);
    }
    ```

-   `run()`: Sets the environment for running the proposal. [Refer](../overview/architecture/proposal-functions.md#run-function) for a detailed explanation. It sets `addresses`, `primaryForkId`, and `governor` and calls `super.run()` to run the proposal lifecycle. In this function, `primaryForkId` is set to `sepolia` and selecting the fork for running the proposal. Next, the `addresses` object is set by reading `addresses.json` file. `addresses` contract state is persisted across forks using `vm.makePersistent()`. Governor OZ contract is set using `setGovernor` that will be used to check on-chain calldata and simulate the proposal.

    ```solidity
    function run() public override {
        // Create and select the sepolia fork for proposal execution.
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        // Set the addresses object by reading addresses from the json file.
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("addresses/Addresses.json"))
            )
        );

        // Make 'addresses' state persist across the selected fork.
        vm.makePersistent(address(addresses));

        // Set Governor oz. This address is used for proposal simulation and checking on-chain proposal state.
        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

        // Call the run function of the parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `validate()`: This final step validates the system in its post-execution state. It ensures that the Governor oz's timelock is the new owner of the Vault and token, the tokens were transferred to Governor oz's timelock, and the token was whitelisted on the Vault contract.

    ```solidity
    function validate() public override {
        // Get the vault address
        Vault governorOZVault = Vault(
            addresses.getAddress("GOVERNOR_OZ_VAULT")
        );

        // Get the token address
        Token token = Token(addresses.getAddress("GOVERNOR_OZ_VAULT_TOKEN"));

        // Get Governor oz's timelock address
        address timelock = addresses.getAddress("GOVERNOR_OZ_TIMELOCK");

        // Ensure the token total supply is 10 million
        assertEq(token.totalSupply(), 10_000_000e18);

        // Ensure the timelock is the owner of the deployed token.
        assertEq(token.owner(), address(timelock));

        // Ensure the timelock is the owner of the deployed vault
        assertEq(governorOZVault.owner(), address(timelock));

        // Ensure the vault is not paused
        assertFalse(governorOZVault.paused());

        // Ensure the token is whitelisted on the vault
        assertTrue(governorOZVault.tokenWhitelist(address(token)));

        // Get the vault's token balance
        uint256 balance = token.balanceOf(address(governorOZVault));

        // Get the timelock deposits in the vault
        (uint256 amount, ) = governorOZVault.deposits(
            address(token),
            address(timelock)
        );

        // Ensure the timelock deposit is the same as the vault's token balance
        assertEq(amount, balance);

        // Ensure all minted tokens are deposited into the vault
        assertEq(
            token.balanceOf(address(governorOZVault)),
            token.totalSupply()
        );
    }
    ```

## Proposal Simulation

First, remove all addresses in `Addresses.json` before running through the tutorial. There are two ways to execute proposals:

1. **Using `forge test`**: Details on this method can be found in the [integration-tests.md](../testing/integration-tests.md) section.
2. **Using `forge script`**: This is the chosen method for this tutorial.

## Running the Proposal with `forge script`

### Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure the cast address is the same as the Deployer address.

If you're missing a wallet in `~/.foundry/keystores/`, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

### Deploying a Governor OZ on Testnet

You'll need a Governor OZ contract set up on the testnet before running the proposal.

We have a script in [script/](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script) folder called `DeployGovernorOz.s.sol` to facilitate this process.

Before running the script, you must add the `DEPLOYER_EOA` address to the `Addresses.json` file.

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

After adding the address, run the script:

```sh
forge script script/DeployGovernorOz.s.sol --rpc-url sepolia --broadcast
-vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in
`~/.foundry/keystores/`.

### Setting Up the Addresses JSON

Copy the addresses of the timelock, governor, and governance token from the script output and add them to the `Addresses.json` file. The file should look like this:

```json
[
    {
        "addr": "YOUR_TIMELOCK_ADDRESS",
        "name": "GOVERNOR_OZ_TIMELOCK",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_GOVERNOR_ADDRESS",
        "name": "GOVERNOR_OZ",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_GOVERNANCE_TOKEN_ADDRESS",
        "chainId": 11155111,
        "isContract": true,
        "name": "GOVERNOR_OZ_GOVERNANCE_TOKEN"
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
forge script src/proposals/simple-vault-governor-oz/GovernorOZProposal_01.sol --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Before you execute the proposal script, double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/`. It's crucial to ensure ${wallet_address} is correctly listed as the deployer address in the Addresses.json file. If these don't align, the script execution will fail.

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          'addr': '0x69A5DfCD97eF074108b480e369CecfD9335565A2',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'GOVERNOR_OZ_VAULT'
},
  {
          'addr': '0x541234b61c081eaAE62c9EF52A633cD2aaf92A05',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'GOVERNOR_OZ_VAULT_TOKEN'
}

---------------- Proposal Description ----------------
  Governor oz proposal mock 1

------------------ Proposal Actions ------------------
  1). calling 0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001 data.
  target: 0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001


  2). calling 0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 with 0 eth and 0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000 data.
  target: 0x541234b61c081eaAE62c9EF52A633cD2aaf92A05
payload
  0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000


  3). calling 0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000 data.
  target: 0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000




------------------ Proposal Calldata ------------------
  0x7d5e81e20000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000380000000000000000000000000000000000000000000000000000000000000000300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a0500000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001b476f7665726e6f72206f7a2070726f706f73616c206d6f636b20310000000000

```

If a password was provide to the wallet, the script will prompt for the password before broadcasting the proposal.

A DAO member can check whether the calldata proposed on the governance matches the calldata from the script exeuction. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually as new contracts have now been added to the system.

The proposal script will deploy the contracts in `deploy()` method and will generate actions calldata for each individual action along with proposal calldata for the proposal. The proposal can be proposed manually using the cast send along with the calldata generated above.
