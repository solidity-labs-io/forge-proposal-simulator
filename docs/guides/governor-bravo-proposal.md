# Governor Bravo Proposal

## Overview

After adding FPS into project dependencies, the next step is the creation of the
first Proposal contract. This example provides guidance on writing a proposal
for deploying new instances of `Vault.sol` and `Token`. These contracts are
located in the fps-example-repo [mocks](https://github.com/solidity-labs-io/fps-example-repo/tree/main/src/mocks). Copy each file in this tutorial into your project, or clone the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/) repo. This tutorial assumes you have cloned the fps-example-repo.

This proposal includes the transfer of ownership of both contracts to Governor Bravo's timelock, along with the whitelisting of the token, minting of tokens to the timelock and timelock depositing tokens into the vault.

## Proposal contract

Here we are using the BravoProposal_01 proposal that is present in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-bravo/BravoProposal_01.sol). We will use this contract as a reference for the tutorial.

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
    ```solidity
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }
    ```
-   `description()`: Provide a detailed description of your proposal.
    ```solidity
    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
    }
    ```
-   `build()`: Set the necessary actions for your proposal, [Refer](../overview/architecture/proposal-functions.md#build-function) for detailed explanation. In this example, ERC20 token is whitelisted on the Vault contract. Then timelock approves token for vault and deposits all tokens into the vault. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address that will call actions is passed into `buildModifier`, it is the governor bravo's timelock for this example. `buildModifier` is necessary modifier for `build` function and will not work without it.

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO"))
    {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get vault address
        address bravoVault = addresses.getAddress("BRAVO_VAULT");

        // Get token address
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

-   `deploy()`: Deploy any necessary contracts. This example demonstrates the deployment of Vault and an ERC20 token. Once the contracts are deployed, they are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // Set governor bravo's timelock as owner for vault and token.
        address owner = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

        // Deploy vault address if not already deployed and transfer ownership to timelock.
        if (!addresses.isAddressSet("BRAVO_VAULT")) {
            Vault bravoVault = new Vault();

            addresses.addAddress("BRAVO_VAULT", address(bravoVault), true);
            bravoVault.transferOwnership(owner);
        }

        // Deploy token address if not already deployed, transfer ownership to timelock
        // and transfer all initial minted tokens from deployer to timelock.
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

-   `validate()`: This final step validates the system in its post-execution state. It ensures that the governor bravo's timelock is the new owner of Vault and token, the tokens were transferred to governor bravo's timelock and the token was whitelisted on the Vault contract

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

-   `run()`: Sets environment for running the proposal. [Refer](../overview/architecture/proposal-functions.md#run-function) for detailed explanation. It sets `addresses`, `primaryForkId` and `governor` and calls `super.run()` to run proposal lifecycle. In this function, `primaryForkId` is set to `sepolia` and selecting the fork for running proposal. Next `addresses` object is set by reading `addresses.json` file. `addresses` contract state is persisted accross forks using `vm.makePersistent()`. Governor bravo contract is set using `setGovernor` that will be used to check onchain calldata and simulate the proposal.

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

## Proposal simulation

First, remove all addresses in `Addresses.json` before running through the tutorial. There are two ways to execute proposals:

1. **Using `forge test`**: Details on this method can be found in the [integration-tests.md](../testing/integration-tests.md) section.
2. **Using `forge script`**: This is the chosen method for this tutorial.

## Running the Proposal with `forge script`

### Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure cast address is same as Deployer address.

If you're missing a wallet in `~/.foundry/keystores/`, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

### Deploying a Governor Bravo on Testnet

You'll need a Bravo Governor contract set up on the testnet before running the proposal.

We have a script in [script/](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script) folder called `DeployGovernorBravo.s.sol` to facilitate this process.

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
forge script script/DeployGovernorBravo.s.sol --rpc-url sepolia --broadcast
-vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in
`~/.foundry/keystores/`.

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

After adding the addresses, run the second script to accept ownership of the timelock and initialize the governor.

The script is called `InitializeBravo.s.sol` and is located in the [script/](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script) folder.
Before running the script, get the eta from the queue transaction on the previous script and set as a environment variable.

```sh
export ETA=123456
```

Run the script:

```sh
forge script script/InitializeBravo.s.sol --rpc-url sepolia --broadcast -vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

### Setting Up the Addresses JSON

Copy the `GOVERNOR_BRAVO_ALPHA` address from the script output and add it to
the `Addresses.json` file. The final Addresses.json file should be something like this:

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
forge script src/proposals/BravoProposal_01.sol --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Before you execute the proposal script, double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/`. It's crucial to ensure ${wallet_address} is correctly listed as the deployer address in the Addresses.json file. If these don't align, the script execution will fail.

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

If a password was provide to the wallet, the script will prompt for the password before broadcasting the proposal.

A DAO member can check whether the calldata proposed on the governance matches the calldata from the script exeuction. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually as new contracts have now been added to the system.

The proposal script will deploy the contracts in `deploy()` method and will generate actions calldata for each individual action along with proposal calldata for the proposal. The proposal can be proposed manually using the cast send along with the calldata generated above.
