# Governor Bravo Proposal

## Overview

After adding FPS into project dependencies, the next step is the creation of the
first Proposal contract. This example provides guidance on writing a proposal
for deploying new instances of `Vault.sol` and `MockToken`. These contracts are
located in the [guides section](./introduction.md#example-contracts). The proposal includes the transfer of ownership of both contracts to Governor Bravo's timelock, along with the whitelisting of the token and minting of tokens to the timelock.

The following contract is present in the `examples/governor-bravo` folder. We will use this contract as a reference for the tutorial.

```solidity
pragma solidity ^0.8.0;

import { Vault } from "@examples/Vault.sol";
import { MockToken } from "@examples/MockToken.sol";
import { GovernorBravoProposal } from "@proposals/GovernorBravoProposal.sol";
import { Proposal } from "@proposals/Proposal.sol";

/// BRAVO_01 proposal deploys a Vault contract and an ERC20 token contract
/// Then the proposal transfers ownership of both Vault and ERC20 to the governor address
/// Finally the proposal whitelist the ERC20 token in the Vault contract
contract BRAVO_01 is GovernorBravoProposal {
    /// @notice Returns the name of the proposal.
    string public override name = "BRAVO_01";

    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";

    /// ADDRESSES_PATH is the path to the Addresses.json file
    /// PROTOCOL_TIMELOCK is the wallet address that will be used to simulate the proposal actions
    constructor() Proposal(ADDRESSES_PATH, "PROTOCOL_TIMELOCK") {
        string memory urlOrAlias = vm.envOr("ETH_RPC_URL", string("sepolia"));
        primaryForkId = vm.createFork(urlOrAlias);
    }

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Governor Bravo proposal mock";
    }

    /// @notice Deploys a vault contract and an ERC20 token contract.
    function deploy() public override {
        if (!addresses.isAddressSet("VAULT")) {
            Vault timelockVault = new Vault();
            addresses.addAddress("VAULT", address(timelockVault), true);
        }

        if (!addresses.isAddressSet("TOKEN_1")) {
            MockToken token = new MockToken();
            addresses.addAddress("TOKEN_1", address(token), true);
        }
    }

    /// @notice steps:
    /// 1. Transfers vault ownership to timelock.
    /// 2. Transfer token ownership to timelock.
    /// 3. Transfers all tokens to timelock.
    function afterDeploy() public override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(timelock);
        token.transferOwnership(timelock);

        // Make sure that DEV is the address you specify in the --sender flag
        token.transfer(
            timelock,
            token.balanceOf(addresses.getAddress("DEPLOYER_EOA"))
        );
    }

    /// @notice Sets up actions for the proposal, in this case, setting the MockToken to active.
    function build() public override {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALL -- mutative and recorded
        Vault(timelockVault).whitelistToken(token, true);
    }

    /// @notice Executes the proposal actions.
    function simulate() public override {
        // Call parent _run function to check if there are actions to execute
        super.simulate();

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        address govToken = addresses.getAddress("PROTOCOL_GOVERNANCE_TOKEN");
        address proposer = addresses.getAddress("DEPLOYER_EOA");

        _simulateActions(governor, govToken, proposer);
    }

    /// @notice Validates the post-execution state.
    function validate() public override {
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
-   `_build()`: Set the necessary actions for your proposal. In this example, ERC20 token is whitelisted on the Vault contract. The actions should be
    written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function.
-   `simulate()`: Execute the proposal actions outlined in the `_build()` step. This
    function performs a call to `_simulateActions` from the inherited
    `GovernorBravoProposal` contract. Internally, `_simulateActions()` uses the calldata generated from the actions set up in the build step, and simulates the end-to-end workflow of a successful proposal submission, starting with a call to [propose](https://github.com/compound-finance/compound-governance/blob/5e581ef817464fdb71c4c7ef6bde4c552302d160/contracts/GovernorBravoDelegate.sol#L118).
-   `_validate()`: This final step is crucial for validating the post-execution state. It ensures that the timelock is the new owner of Vault and token, the tokens were transferred to timelock and the token was whitelisted on the Vault contract

Constructor parameters are passed to the `Proposal` contract. The
`ADDRESSES_PATH` is the path to the `Addresses.json` file, and `PROTOCOL_TIMELOCK` is
the timelock that will be used to simulate the proposal actions. The
`primaryForkId` is the RPC URL or alias of the blockchain that will be used to
simulate the proposal actions and broadcast if any contract deployment is required.

With the first proposal contract prepared, it's time to proceed with execution. There are two options available:

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

### Deploying a Governor Bravo on Testnet

You'll need a Bravo Governor contract set up on the testnet before running the proposal.

We have a script in `script/` folder called `DeployGovernorBravo.s.sol` to facilitate this process.

```sh
forge script script/DeployGovernorBravo.s.sol --rpc-url sepolia --broadcast
-vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in
`~/.foundry/keystores/`.

Copy the addresses of the timelock, governor, and governance token from the script output and add them to the `Addresses.json` file.

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
        "name": "PROTOCOL_GOVERNOR",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_GOVERNANCE_TOKEN_ADDRESS",
        "chainId": 11155111,
        "isContract": true,
        "name": "PROTOCOL_GOVERNANCE_TOKEN"
    }
]
```

After adding the addresses, run the second script to accept ownership of
the timelock and initialize the governor.

The script is called `InitializeBravo.s.sol` and is located in the `script/` folder.
Before running the script, get the eta from the queue transaction on the
previous script and set as a environment variable.

```sh
export ETA=123456
```

Run the script:

```sh
forge script script/InitializeBravo.s.sol --rpc-url sepolia --broadcast -vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Copy the _PROTOCOL_GOVERNOR_ALPHA_ address from the script output and add it to
the `Addresses.json` file.

### Setting Up the Addresses JSON

The last step before running the proposal is to add the DEV address
to Address.json. The final Address.json file should be something like this:

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
        "name": "PROTOCOL_GOVERNOR",
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
        "name": "PROTOCOL_GOVERNOR_ALPHA",
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
forge script examples/governor-bravo/BRAVO_01.sol -vvvv --slow
--sender ${wallet_address} -vvvv --account
${wallet_name} -g 200
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
          'addr': '0x0957D5577ea1561e111af0cb7c6949CBd6cAF4af',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'VAULT'
},
  {
          'addr': '0x6CF2d43DCDd27FaC5ef82600270F595c8a134b15',
          'chainId': 11155111,
          'isContract': true ,
          'name': 'TOKEN_1'
}


---------------- Proposal Description ----------------
  Governor Bravo proposal mock


------------------ Proposal Actions ------------------
  1). calling 0x0957d5577ea1561e111af0cb7c6949cbd6caf4af with 0 eth and 0ffb1d8b0000000000000000000000006cf2d43dcdd27fac5ef82600270f595c8a134b150000000000000000000000000000000000000000000000000000000000000001 data.
  target: 0x0957D5577ea1561e111af0cb7c6949CBd6cAF4af
payload
  0x0ffb1d8b0000000000000000000000006cf2d43dcdd27fac5ef82600270f595c8a134b150000000000000000000000000000000000000000000000000000000000000001




------------------ Proposal Calldata ------------------
  0xda95691a00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000957d5577ea1561e111af0cb7c6949cbd6caf4af000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000006cf2d43dcdd27fac5ef82600270f595c8a134b15000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c476f7665726e6f7220427261766f2070726f706f73616c206d6f636b00000000
  0xda95691a00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000024000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000957d5577ea1561e111af0cb7c6949cbd6caf4af000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000006cf2d43dcdd27fac5ef82600270f595c8a134b15000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c476f7665726e6f7220427261766f2070726f706f73616c206d6f636b00000000

```

If a password was provide to the wallet, the script will prompt for the password before broadcasting the proposal.

A DAO member can check whether the calldata proposed on the governance matches
the calldata from the script exeuction. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.
