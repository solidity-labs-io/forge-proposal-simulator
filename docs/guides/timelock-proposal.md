# Timelock Proposal

## Overview

After integrating FPS into the project dependencies, the next step involves creating the first Proposal contract. This example serves as a guide for drafting a proposal to deploy new instances of `Vault.sol` and `Token`, whitelist `Token` on `Vault`, approve and deposit all tokens into `Vault`. These contracts are located in the fps-example-repo [mocks](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/mocks). Clone the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/) repo before continuing the tutorial.

This proposal entails transferring ownership of both contracts to a timelock, along with whitelisting the token, minting tokens to the timelock, and having the timelock deposit tokens into the vault.

## Proposal Contract

In this example, we are using the TimelockProposal_01 proposal that is present in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-timelock/TimelockProposal_01.sol). We will use this contract as a reference for the tutorial.

Let's review each of the functions that are overridden.

-   `name()`: This function defines the name of your proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "TIMELOCK_MOCK";
    }
    ```

-   `description()`: It provides a detailed description of your proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return "Timelock proposal mock";
    }
    ```

-   `deploy()`: This function deploys any necessary contracts. In this example, it demonstrates the deployment of Vault and an ERC20 token. Once the contracts are deployed, they are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // Deploy vault address if not already deployed and transfer ownership to timelock.
        if (!addresses.isAddressSet("TIMELOCK_VAULT")) {
            Vault timelockVault = new Vault();

            addresses.addAddress(
                "TIMELOCK_VAULT",
                address(timelockVault),
                true
            );

            timelockVault.transferOwnership(address(timelock));
        }

        // Deploy token address if not already deployed, transfer ownership to timelock
        // and transfer all initial minted tokens from deployer to timelock.
        if (!addresses.isAddressSet("TIMELOCK_TOKEN")) {
            Token token = new Token();
            addresses.addAddress("TIMELOCK_TOKEN", address(token), true);
            token.transferOwnership(address(timelock));

            // During forge script execution, the deployer of the contracts is
            // the DEPLOYER_EOA. However, when running through forge test, the deployer of the contracts is this contract.
            uint256 balance = token.balanceOf(address(this)) > 0
                ? token.balanceOf(address(this))
                : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));

            token.transfer(address(timelock), balance);
        }
    }
    ```

    Since these changes do not persist from runs themselves, after the contracts are deployed, the user must update the Addresses.json file with the newly deployed contract addresses.

-   `build()`: Add actions to the proposal contract. [See build function](../overview/architecture/proposal-functions.md#build-function). In this example, it whitelists the ERC20 token on the Vault contract, approves the token for the vault, and deposits all tokens into the vault. The actions should be written in Solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`; it is the timelock for this example. `buildModifier` is a necessary modifier for the `build` function and will not work without it.

    ```solidity
    function build() public override buildModifier(address(timelock)) {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get vault address
        address timelockVault = addresses.getAddress("TIMELOCK_VAULT");

        // Get token address
        address token = addresses.getAddress("TIMELOCK_TOKEN");

        // Get timelock's token balance.
        uint256 balance = Token(token).balanceOf(address(timelock));

        /// CALLS -- mutative and recorded

        // Whitelists the deployed token on the deployed vault.
        Vault(timelockVault).whitelistToken(token, true);

        // Approve the token for the vault.
        Token(token).approve(timelockVault, balance);

        // Deposit all tokens into the vault.
        Vault(timelockVault).deposit(token, balance);
    }
    ```

-   `run()`: Sets up the environment for running the proposal. [See run function](../overview/architecture/proposal-functions.md#run-function). This sets `addresses`, `primaryForkId`, and `timelock` and calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `sepolia` for running the proposal. Next, the `addresses` object is set by reading the `addresses.json` file. The `addresses` contract state is persistent across forks foundry's `vm.makePersistent()` cheatcode. The timelock address to simulate the proposal through is set using `setTimelock`. This will be used to check onchain calldata and simulate the proposal.

    ```solidity
    function run() public override {
        // Create and select the sepolia fork for proposal execution
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        // Set the addresses object by reading addresses from the json file
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("addresses/Addresses.json"))
            )
        );

        // Make the 'addresses' state persist across the selected fork
        vm.makePersistent(address(addresses));

        // Set the timelock; this address is used for proposal simulation and checking on-chain proposal state
        setTimelock(addresses.getAddress("PROTOCOL_TIMELOCK"));

        // Call the run function of the parent contract 'Proposal.sol'
        super.run();
    }
    ```

-   `simulate()`: This function executes the proposal actions outlined in the `build()` step. It performs a call to `_simulateActions` from the inherited `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [scheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.

    ```solidity
    function simulate() public override {
        // Get dev address for simulation
        address dev = addresses.getAddress("DEPLOYER_EOA");

        /// Dev is proposer and executor of timelock
        _simulateActions(dev, dev);
    }
    ```

-   `validate()`: This final step validates the system in its post-execution state. It ensures that the timelock is the new owner of the Vault and token, the tokens were transferred to the timelock, and the token was whitelisted on the Vault contract.

    ```solidity
    function validate() public override {
        // Get vault address
        Vault timelockVault = Vault(addresses.getAddress("TIMELOCK_VAULT"));

        // Get token address
        Token token = Token(addresses.getAddress("TIMELOCK_TOKEN"));

        // Ensure the total supply of tokens is 10 million
        assertEq(token.totalSupply(), 10_000_000e18);

        // Ensure the timelock is the owner of the deployed token
        assertEq(token.owner(), address(timelock));

        // Ensure the timelock is the owner of the deployed vault
        assertEq(timelockVault.owner(), address(timelock));

        // Ensure the vault is not paused
        assertFalse(timelockVault.paused());

        // Ensure the token is whitelisted on the vault
        assertTrue(timelockVault.tokenWhitelist(address(token)));

        // Get the vault's token balance
        uint256 balance = token.balanceOf(address(timelockVault));

        // Get the timelock deposits in the vault
        (uint256 amount, ) = timelockVault.deposits(
            address(token),
            address(timelock)
        );

        // Ensure the timelock deposit is the same as the vault's token balance
        assertEq(amount, balance);

        // Ensure all minted tokens are deposited into the vault
        assertEq(token.balanceOf(address(timelockVault)), token.totalSupply());
    }
    ```

## Proposal Simulation

To begin, clear all addresses in `Addresses.json` before proceeding with the tutorial. There are two methods for executing proposals:

1. **Using `forge test`**: Refer to the [integration-tests.md](../testing/integration-tests.md) section for detailed instructions on this method.
2. **Using `forge script`**: This tutorial focuses on using this method.

### Running the Proposal with `forge script`

#### Setting Up Your Deployer Address

The deployer address is utilized to broadcast transactions deploying the proposal contracts. Ensure your deployer address holds sufficient funds from the faucet to cover deployment costs on the testnet. Emphasizing security in private key management, we avoid storing the private key as an environment variable. Instead, we utilize Foundry's cast tool. Ensure the cast address matches the Deployer address.

If there are no wallets in the `~/.foundry/keystores/` folder, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

#### Deploying a Timelock Controller on Testnet

Before executing the proposal, set up a Timelock Controller contract on the testnet. We provide a script [DeployTimelock](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script/DeployTimelock.s.sol) to streamline this process.

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

After adding the addresses, execute the script:

```sh
forge script script/DeployTimelock.s.sol --broadcast --rpc-url
sepolia --slow --sender ${wallet_address} --account ${wallet_name} -vvv
```

Ensure that the ${wallet_name} and ${wallet_address} accurately correspond to the wallet details saved in `~/.foundry/keystores/`.

#### Setting Up the Addresses JSON

Add the Timelock Controller address to the JSON file. The structure should resemble this:

```json
[
    {
        "addr": "YOUR_TIMELOCK_ADDRESS",
        "name": "PROTOCOL_TIMELOCK",
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

#### Running the Proposal

```sh
forge script src/proposals/simple-vault-timelock/TimelockProposal_01.sol --account ${wallet_name} --broadcast --slow --sender ${wallet_address} -vvvv
```

Before executing the proposal script, ensure that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/`. It's essential to verify that ${wallet_address} is correctly listed as the deployer address in the Addresses.json file. Failure to align these details will result in script execution failure.

The script will output the following:

```sh
Timelock output:
== Logs ==


--------- Addresses added ---------
  {
          'addr': '0xF9C26968C2d4E1C2ADA13c6323be31c1067EBB7c',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'TIMELOCK_VAULT'
},
  {
          'addr': '0x2A2A18A71d0eA4B97ebb18D3820cd3625C3A1465',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'TIMELOCK_TOKEN'
}

---------------- Proposal Description ----------------
  Timelock proposal mock

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




------------------ Schedule Calldata ------------------
  0x8f2a0bb000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000000eff0dbf88af0664ed6d8db81251aaaeac77a977f015bb9bf3d34c91b1bf988a6000000000000000000000000000000000000000000000000000000000000003c0000000000000000000000000000000000000000000000000000000000000003000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c00000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a14650000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef240000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000


------------------ Execute Calldata ------------------
  0xe38335e500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000000eff0dbf88af0664ed6d8db81251aaaeac77a977f015bb9bf3d34c91b1bf988a60000000000000000000000000000000000000000000000000000000000000003000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c00000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a14650000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef240000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000
```

It's crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be manually added to ensure accuracy.

The proposal script will deploy the contracts in the `deploy()` method and will generate action calldata for each individual action, along with schedule and execute calldatas for the proposal. The proposal can be scheduled and executed manually using the cast send along with the calldata generated above.
