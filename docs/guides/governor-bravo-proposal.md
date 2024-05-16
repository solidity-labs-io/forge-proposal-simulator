# Governor Bravo Proposal

## Overview

After adding FPS into project dependencies, the next step is the creation of the
first Proposal contract. This example provides guidance on writing a proposal
for deploying new instances of `Vault.sol` and `Token`. These contracts are
located in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/tree/feat/test-cleanup/src/mocks). Copy each file used in this tutorial into your project for running examples or clone [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/) repo and you have everything setup there. Please remove all addresses in `Addresses.json` before running through the tutorial `fps-example-repo`.
The proposal includes the transfer of ownership of both contracts to Governor Bravo's timelock, along with the whitelisting of the token, minting of tokens to the timelock and timelock depositing tokens into the vault.

The following contract is present in the [src/proposals/](https://github.com/solidity-labs-io/fps-example-repo/tree/feat/test-cleanup/src/proposals) folder. We will use this contract as a reference for the tutorial.

```solidity
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { GovernorBravoProposal } from "@forge-proposal-simulator/src/proposals/GovernorBravoProposal.sol";
import { IGovernorBravo } from "@forge-proposal-simulator/src/interface/IGovernorBravo.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { Vault } from "src/mocks/Vault.sol";
import { Token } from "src/mocks/Token.sol";

contract BravoProposal_01 is GovernorBravoProposal {
    function name() public pure override returns (string memory) {
        return "BRAVO_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Bravo proposal mock";
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

        setGovernor(addresses.getAddress("PROTOCOL_GOVERNOR"));

        super.run();
    }

    function deploy() public override {
        address owner = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");
        if (!addresses.isAddressSet("BRAVO_VAULT")) {
            Vault bravoVault = new Vault();

            addresses.addAddress("BRAVO_VAULT", address(bravoVault), true);
            bravoVault.transferOwnership(owner);
        }

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

    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO"))
    {
        /// STATICCALL -- not recorded for the run stage
        address bravoVault = addresses.getAddress("BRAVO_VAULT");
        address token = addresses.getAddress("BRAVO_VAULT_TOKEN");
        uint256 balance = Token(token).balanceOf(
            addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO")
        );

        Vault(bravoVault).whitelistToken(token, true);

        /// CALLS -- mutative and recorded
        Token(token).approve(bravoVault, balance);
        Vault(bravoVault).deposit(token, balance);
    }

    function validate() public override {
        Vault bravoVault = Vault(addresses.getAddress("BRAVO_VAULT"));
        Token token = Token(addresses.getAddress("BRAVO_VAULT_TOKEN"));

        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK_BRAVO");

        uint256 balance = token.balanceOf(address(bravoVault));
        (uint256 amount, ) = bravoVault.deposits(
            address(token),
            address(timelock)
        );
        assertEq(amount, balance);

        assertTrue(bravoVault.tokenWhitelist(address(token)));

        assertEq(token.balanceOf(address(bravoVault)), token.totalSupply());

        assertEq(token.totalSupply(), 10_000_000e18);

        assertEq(token.owner(), address(timelock));

        assertEq(bravoVault.owner(), address(timelock));

        assertFalse(bravoVault.paused());
    }
}
```

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `run()`: Sets environment for running the proposal. `addresses` is address object
    containing addresses to be used in proposal that are fetched from `Addresses.json`. `primaryForkId` is the RPC URL or alias of the blockchain that will be used to
    simulate the proposal actions and broadcast if any contract deployment is required.`governor` is the address of the governor contract.
-   `deploy()`: Deploy any necessary contracts. This example demonstrates the
    deployment of Vault and an ERC20 token. Once the contracts are deployed,
    they are added to the `Addresses` contract by calling `addAddress()`.
-   `build()`: Set the necessary actions for your proposal. In this example, ERC20 token is
    whitelisted on the Vault contract. The actions should be
    written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address is passed into `buildModifier` that will call actions in `build`, that is governor bravo's timelock in this example.
-   `validate()`: This final step is crucial for validating the post-execution state. It
    ensures that the timelock is the new owner of Vault and token, the tokens were transferred to timelock and the token was whitelisted on the Vault contract

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

We have a script in [script/](https://github.com/solidity-labs-io/fps-example-repo/tree/feat/test-cleanup/script) folder called `DeployGovernorBravo.s.sol` to facilitate this process.

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
        "name": "GOVERNOR_BRAVO",
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

The script is called `InitializeBravo.s.sol` and is located in the [script/](https://github.com/solidity-labs-io/fps-example-repo/tree/feat/test-cleanup/script) folder.
Before running the script, get the eta from the queue transaction on the
previous script and set as a environment variable.

```sh
export ETA=123456
```

Run the script:

```sh
forge script script/InitializeBravo.s.sol --rpc-url sepolia --broadcast -vvvv --slow --sender ${wallet_address} -vvvv --account ${wallet_name} -g 200
```

Copy the _GOVERNOR_BRAVO_ALPHA_ address from the script output and add it to
the `Addresses.json` file.

### Setting Up the Addresses JSON

The last step before running the proposal is to add the DEPLOYER_EOA address
to Addresses.json. The final Addresses.json file should be something like this:

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
          'name': 'TOKEN'
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
