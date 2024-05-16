# Timelock Proposal

## Overview

After adding FPS into project dependencies, the next step is the creation of the
first Proposal contract. This example provides guidance on writing a proposal
for deploying new instances of `Vault.sol` and `Token`. These contracts are
located in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/tree/feat/test-cleanup/src/mocks). Copy each file used in this tutorial into your project for running examples or clone [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/) repo and you have everything setup there. Please remove all addresses in `Addresses.json` before running through the tutorial `fps-example-repo`.
The proposal includes the transfer of ownership of both contracts to timelock controller, along with the whitelisting of the token, minting of tokens to the timelock controller and timelock controller depositing tokens into the vault.

The following contract is present in the [src/proposals/](https://github.com/solidity-labs-io/fps-example-repo/tree/feat/test-cleanup/src/proposals) folder. We will use this contract as a reference for the tutorial.

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
-   `run()`: Sets environment for running the proposal. `addresses` is address object
    containing addresses to be used in proposal that are fetched from `Addresses.json`. `primaryForkId` is the RPC URL or alias of the blockchain that will be used to
    simulate the proposal actions and broadcast if any contract deployment is required.`timelock` is the address of the timelock controller contract.
-   `deploy()`: Deploy any necessary contracts. This example demonstrates the
    deployment of Vault and an ERC20 token. Once the contracts are deployed,
    they are added to the `Addresses` contract by calling `addAddress()`.
-   `build()`: Set the necessary actions for your proposal. In this example,
    ERC20 token is whitelisted on the Vault contract. The actions should be
    written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address is passed into `buildModifier` that will call actions in `build`, that is timelock controller in this example.
-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This
    function performs a call to `_simulateActions` from the inherited
    `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [scheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.
-   `validate()`: This final step is crucial for validating the post-execution state. It
    ensures that the timelock is the new owner of Vault and token, the tokens were transferred to timelock and the token was whitelisted on the Vault contract

With the proposal contract prepared, it can now be executed. There are two options available:

1. **Using `forge test`**: Details on this method can be found in the [integration-tests.md](../testing/integration-tests.md "mention") section.
2. **Using `forge script`**: This is the chosen method for this tutorial.

## Running the Proposal with `forge script`

### Setting Up Your Deployer Address

The deployer address is the the one you'll use to broadcast the transactions
deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet.

We prioritize security when it comes to private key management. To avoid storing
the private key as an environment variable, we use Foundry's cast tool.

If you're missing a wallet in `~/.foundry/keystores/`, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

### Deploying a Timelock Controller on Testnet

You'll need a Timelock Controller contract set up on the testnet before running the proposal.

We have a script in [script/](https://github.com/solidity-labs-io/fps-example-repo/tree/feat/test-cleanup/script) folder called `DeployTimelock.s.sol` to facilitate this process.

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

Add the Timelock Controller address and deployer address to it. The file should look like this:

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

Before you execute the proposal script, double-check that the ${wallet_name} and
${wallet_address} accurately match the wallet details saved in
`~/.foundry/keystores/`. It's crucial to ensure ${wallet_address} is correctly
listed as the deployer address in the Addresses.json file. If these don't align,
the script execution will fail.

The script will output the following:

```sh
== Logs ==

--------- Addresses added after running proposal ---------
  {
          'addr': '0x61A7A6F1553cbB39c87959623bb23833838406D7',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'VAULT'
},
  {
          'addr': '0x7E1bF35E2B30Ae6b62B59a93C49F9cf32b273931',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'TOKEN_1'
}


---------------- Proposal Description ----------------
  Timelock proposal mock


------------------ Proposal Actions ------------------
  1). calling 0x61a7a6f1553cbb39c87959623bb23833838406d7 with 0 eth and 0ffb1d8b0000000000000000000000007e1bf35e2b30ae6b62b59a93c49f9cf32b2739310000000000000000000000000000000000000000000000000000000000000001 data.
  target: 0x61A7A6F1553cbB39c87959623bb23833838406D7
payload
  0x0ffb1d8b0000000000000000000000007e1bf35e2b30ae6b62b59a93c49f9cf32b2739310000000000000000000000000000000000000000000000000000000000000001




------------------ Schedule Calldata ------------------
  0x8f2a0bb000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000000b35b0f64616e9b2247498c7c78dbbce9cdcf25dbb3ad7c086d567166535d9b42000000000000000000000000000000000000000000000000000000000000003c000000000000000000000000000000000000000000000000000000000000000100000000000000000000000061a7a6f1553cbb39c87959623bb23833838406d7000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000007e1bf35e2b30ae6b62b59a93c49f9cf32b273931000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000


------------------ Execute Calldata ------------------
  0xe38335e500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000b35b0f64616e9b2247498c7c78dbbce9cdcf25dbb3ad7c086d567166535d9b42000000000000000000000000000000000000000000000000000000000000000100000000000000000000000061a7a6f1553cbb39c87959623bb23833838406d7000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000007e1bf35e2b30ae6b62b59a93c49f9cf32b273931000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000
```

As the Timelock executor, you have the ability to run the script to execute the proposal. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.
