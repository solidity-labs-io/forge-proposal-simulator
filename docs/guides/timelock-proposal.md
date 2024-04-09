# Timelock Proposal

## Overview

After adding FPS into project dependencies, the next step is the creation of the first Proposal contract. This example provides guidance on writing a proposal for deploying new instances of `Vault.sol` and `MockToken`. These contracts are located in the [guides section](./introduction.md#example-contracts). The proposal includes the transfer of ownership of both contracts to the timelock controller, along with the whitelisting of the token and minting of tokens to the timelock.

The following contract is present in the `examples/timelock` folder. We will use this contract as a reference for the tutorial.

```solidity
pragma solidity ^0.8.0;

import { Vault } from "@examples/Vault.sol";
import { MockToken } from "@examples/MockToken.sol";
import { TimelockProposal } from "@proposals/TimelockProposal.sol";
import { Proposal } from "@proposals/Proposal.sol";

// TIMELOCK_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the timelock address
// Finally the proposal whitelist the ERC20 token in the Vault contract
contract TIMELOCK_01 is TimelockProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    /// ADDRESSES_PATH is the path to the Addresses.json file
    /// PROTOCOL_TIMELOCK is the wallet address that will be used to simulate the proposal actions
    constructor() Proposal(ADDRESSES_PATH, "PROTOCOL_TIMELOCK") {}

    /// @notice Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "TIMELOCK_01";
    }

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Timelock proposal mock";
    }

    /// @notice Deploys a vault contract and an ERC20 token contract.
    function _deploy() internal override {
        if (!addresses.isAddressSet("VAULT")) {
            Vault timelockVault = new Vault();
            addresses.addAddress("VAULT", address(timelockVault), true);
        }

        if (!addresses.isAddressSet("TOKEN_1")) {
            MockToken token = new MockToken();
            addresses.addAddress("TOKEN_1", address(token), true);
        }
    }

    // @notice Transfers vault ownership to timelock.
    //         Transfer token ownership to timelock.
    //         Transfers all tokens to timelock.
    function _afterDeploy() internal override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(timelock);
        token.transferOwnership(timelock);
        // Make sure that DEPLOYER is the address you specify in the --sender flag
        token.transfer(
            timelock,
            token.balanceOf(addresses.getAddress("DEPLOYER"))
        );
    }

    // @notice Set up actions for the proposal, in this case, setting the MockToken to active.
    function _build() internal override {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALLS -- mutative and recorded
        Vault(timelockVault).whitelistToken(token, true);
    }

    // @notice Executes the proposal actions.
    function _run() internal override {
        // Call parent _run function to check if there are actions to execute
        super._run();

        address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
        address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

        _simulateActions(proposer, executor);
    }

    // @notice Validates the post-execution state.
    function _validate() internal override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        assertEq(timelockVault.owner(), timelock);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), timelock);
        assertEq(token.balanceOf(timelock), token.totalSupply());
    }
}
```

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `_deploy()`: Deploy any necessary contracts. This example demonstrates the
    deployment of Vault and an ERC20 token. Once the contracts are deployed,
    they are added to the `Addresses` contract by calling `addAddress()`.
-   `_build()`: Set the necessary actions for your proposal. In this example,
    ERC20 token is whitelisted on the Vault contract. The actions should be
    written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function.
-   `_run()`: Execute the proposal actions outlined in the `_build()` step. This
    function performs a call to `_simulateActions` from the inherited
    `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [scheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.
-   `_validate()`: This final step is crucial for validating the post-execution state. It ensures that the timelock is the new owner of Vault and token, the tokens were transferred to timelock and the token was whitelisted on the Vault contract

Constructor parameters are passed to the `Proposal` contract. The
`ADDRESSES_PATH` is the path to the `Addresses.json` file, and `PROTOCOL_TIMELOCK` is
the timelock that will be used to simulate the proposal actions.

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

We have a script in `script/` folder called `DeployTimelock.s.sol` to facilitate this process.

Before running the script, you must add the `TIMELOCK_PROPOSER`and
`TIMELOCK_EXECUTOR` addresses to the `Addresses.json` file.

```json
[
    {
        "addr": "YOUR_TIMELOCK_PROPOSER_ADDRESS",
        "name": "TIMELOCK_PROPOSER",
        "chainId": 31337,
        "isContract": false
    },
    {
        "addr": "YOUR_TIMELOCK_EXECUTOR_ADDRESS",
        "name": "TIMELOCK_EXECUTOR",
        "chainId": 31337,
        "isContract": false
    }
]
```

After adding the addresses, run the script:

```sh
forge script script/DeployTimelock.s.sol --account testnet --broadcast --rpc-url
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
        "addr": "YOUR_TIMELOCK_PROPOSER_ADDRESS",
        "name": "TIMELOCK_PROPOSER",
        "chainId": 11155111,
        "isContract": false
    },
    {
        "addr": "YOUR_TIMELOCK_EXECUTOR_ADDRESS",
        "name": "TIMELOCK_EXECUTOR",
        "chainId": 11155111,
        "isContract": false
    },
    {
        "addr": "YOUR_DEPLOYER_EOA",
        "name": "DEPLOYER",
        "chainId": 11155111,
        "isContract": false
    }
]
```

### Running the Proposal

```sh
forge script examples/timelock/TIMELOCK_01.sol --account ${wallet_name} --broadcast --fork-url sepolia --slow --sender ${wallet_address} -vvvv
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
