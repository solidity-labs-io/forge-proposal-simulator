# Timelock Proposal

## Overview

After adding FPS into project dependencies, the next step is the creation of the
first Proposal contract. This example provides guidance on writing a proposal
for deploying new instances of `Vault.sol` and `Token`. These contracts are
located in the fps-example-repo [mocks](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/mocks). Copy each file in this tutorial into your project, or clone the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/) repo. This tutorial assumes you have cloned the fps-example-repo.

This proposal includes the transfer of ownership of both contracts to timelock, along with the whitelisting of the token, minting of tokens to the timelock and timelock depositing tokens into the vault.

## Proposal contract

The following contract is present in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-timelock/TimelockProposal_01.sol). We will use this contract as a reference for the tutorial.

```solidity
pragma solidity ^0.8.0;

import { TimelockProposal } from "@forge-proposal-simulator/src/proposals/TimelockProposal.sol";
import { ITimelockController } from "@forge-proposal-simulator/src/interface/ITimelockController.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { Vault } from "src/mocks/Vault.sol";
import { Token } from "src/mocks/Token.sol";

contract TimelockProposal_01 is TimelockProposal {
    function name() public pure override returns (string memory) {
        return "TIMELOCK_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Timelock proposal mock";
    }

    function run() public override {
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("addresses/Addresses.json"))
            )
        );
        vm.makePersistent(address(addresses));

        setTimelock(addresses.getAddress("PROTOCOL_TIMELOCK"));

        super.run();
    }

    function deploy() public override {
        if (!addresses.isAddressSet("TIMELOCK_VAULT")) {
            Vault timelockVault = new Vault();

            addresses.addAddress(
                "TIMELOCK_VAULT",
                address(timelockVault),
                true
            );

            timelockVault.transferOwnership(address(timelock));
        }

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

    function build() public override buildModifier(address(timelock)) {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("TIMELOCK_VAULT");
        address token = addresses.getAddress("TIMELOCK_TOKEN");
        uint256 balance = Token(token).balanceOf(address(timelock));

        Vault(timelockVault).whitelistToken(token, true);

        /// CALLS -- mutative and recorded
        Token(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    function simulate() public override {
        address dev = addresses.getAddress("DEPLOYER_EOA");

        /// Dev is proposer and executor
        _simulateActions(dev, dev);
    }

    function validate() public override {
        Vault timelockVault = Vault(addresses.getAddress("TIMELOCK_VAULT"));
        Token token = Token(addresses.getAddress("TIMELOCK_TOKEN"));

        uint256 balance = token.balanceOf(address(timelockVault));
        (uint256 amount, ) = timelockVault.deposits(
            address(token),
            address(timelock)
        );
        assertEq(amount, balance);

        assertTrue(timelockVault.tokenWhitelist(address(token)));

        assertEq(token.balanceOf(address(timelockVault)), token.totalSupply());

        assertEq(token.totalSupply(), 10_000_000e18);

        assertEq(token.owner(), address(timelock));

        assertEq(timelockVault.owner(), address(timelock));

        assertFalse(timelockVault.paused());
    }
}
```

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `run()`: Sets environment for running the proposal. It sets `addresses`, `primaryForkId` and `timelock`. `addresses` is address object
    containing addresses to be used in proposal that are fetched from `Addresses.json`. `primaryForkId` is the RPC URL or alias of the blockchain that will be used to simulate the proposal actions and broadcast if any contract deployment is required.`timelock` is the address of the timelock controller contract.
-   `deploy()`: Deploy any necessary contracts. This example demonstrates the deployment of Vault and an ERC20 token. Once the contracts
    are deployed, they are added to the `Addresses` contract by calling `addAddress()`.
-   `build()`: Set the necessary actions for your proposal. In this example,
    ERC20 token is whitelisted on the Vault contract. The actions should be
    written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address that will call actions is passed into `buildModifier`, it is the timelock controller for this example.
-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This
    function performs a call to `_simulateActions` from the inherited
    `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [scheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.
-   `validate()`: This final step validates the system in its post-execution state. It
    ensures that the timelock is the new owner of Vault and token, the tokens were transferred to timelock and the token was whitelisted on the Vault contract

## Proposal simulation

First of all, remove all addresses in `Addresses.json` before running through the tutorial. To proceed with execution, there are two options available:

1. **Using `forge test`**: Details on this method can be found in the [integration-tests.md](../testing/integration-tests.md) section.
2. **Using `forge script`**: This is the chosen method for this tutorial.

## Running the Proposal with `forge script`

### Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure cast address is same as Deployer address.

If you're missing a wallet in `~/.foundry/keystores/`, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

### Deploying a Timelock Controller on Testnet

You'll need a Timelock Controller contract set up on the testnet before running the proposal.

We have a script in [script/](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script) folder called `DeployTimelock.s.sol` to facilitate this process.

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

After adding the addresses, run the script:

```sh
forge script script/DeployTimelock.s.sol --broadcast --rpc-url
sepolia --slow --sender ${wallet_address} --account ${wallet_name} -vvv
```

Double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in
`~/.foundry/keystores/`.

### Setting Up the Addresses JSON

Add the Timelock Controller address to the json file. The file should look like this:

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

### Running the Proposal

```sh
forge script src/proposals/TimelockProposal_01.sol --account ${wallet_name} --broadcast --slow --sender ${wallet_address} -vvvv
```

Before you execute the proposal script, double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/`. It's crucial to ensure ${wallet_address} is correctly listed as the deployer address in the Addresses.json file. If these don't align, the script execution will fail.

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

It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.

The proposal script will deploy the contracts in `deploy()` method and will generate actions calldata for each individual action along with schedule and execute calldatas for the proposal. The proposal can be scheduled and executed manually using the cast send along with the calldata generated above.
