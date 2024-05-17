# Multisig Proposal

## Overview

After adding FPS into project dependencies, the next step is the creation of the
first Proposal contract. This example provides guidance on writing a proposal
for deploying new instances of `Vault.sol` and `Token`. These contracts are
located in the fps-example-repo [mocks](https://github.com/solidity-labs-io/fps-example-repo/tree/main/src/mocks). Copy each file used in this tutorial into your project for running examples or clone [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/) repo and you have everything setup there. For this tutorial it's assumed that you have cloned the fps-example-repo.

This proposal includes the transfer of ownership of both contracts to multisig, along with the whitelisting of the token, minting of tokens to the multisig and multisig depositing tokens into the vault.

## Proposal contract

The following contract is present in the [src/proposals/](https://github.com/solidity-labs-io/fps-example-repo/tree/main/src/proposals) folder. We will use this contract as a reference for the tutorial.

```solidity
pragma solidity ^0.8.0;

import { MultisigProposal } from "@forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { Vault } from "src/mocks/Vault.sol";
import { Token } from "src/mocks/Token.sol";

contract MultisigProposal_01 is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MULTISIG_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Multisig proposal mock";
    }

    function run() public override {
        primaryForkId = vm.createFork("sepolia");

        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("addresses/Addresses.json"))
            )
        );
        vm.makePersistent(address(addresses));

        super.run();
    }

    function deploy() public override {
        address multisig = addresses.getAddress("DEV_MULTISIG");
        if (!addresses.isAddressSet("MULTISIG_VAULT")) {
            Vault multisigVault = new Vault();

            addresses.addAddress(
                "MULTISIG_VAULT",
                address(multisigVault),
                true
            );

            multisigVault.transferOwnership(multisig);
        }

        if (!addresses.isAddressSet("MULTISIG_TOKEN")) {
            Token token = new Token();
            addresses.addAddress("MULTISIG_TOKEN", address(token), true);
            token.transferOwnership(multisig);

            // During forge script execution, the deployer of the contracts is
            // the DEPLOYER_EOA. However, when running through forge test, the deployer of the contracts is this contract.
            uint256 balance = token.balanceOf(address(this)) > 0
                ? token.balanceOf(address(this))
                : token.balanceOf(addresses.getAddress("DEPLOYER_EOA"));

            token.transfer(multisig, balance);
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("DEV_MULTISIG"))
    {
        address multisig = addresses.getAddress("DEV_MULTISIG");

        /// STATICCALL -- not recorded for the run stage
        address multisigVault = addresses.getAddress("MULTISIG_VAULT");
        address token = addresses.getAddress("MULTISIG_TOKEN");
        uint256 balance = Token(token).balanceOf(address(multisig));

        Vault(multisigVault).whitelistToken(token, true);

        /// CALLS -- mutative and recorded
        Token(token).approve(multisigVault, balance);
        Vault(multisigVault).deposit(token, balance);
    }

    function simulate() public override {
        address multisig = addresses.getAddress("DEV_MULTISIG");

        _simulateActions(multisig);
    }

    function validate() public override {
        Vault multisigVault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));
        address multisig = addresses.getAddress("DEV_MULTISIG");

        uint256 balance = token.balanceOf(address(multisigVault));
        (uint256 amount, ) = multisigVault.deposits(address(token), multisig);
        assertEq(amount, balance);

        assertTrue(multisigVault.tokenWhitelist(address(token)));

        assertEq(token.balanceOf(address(multisigVault)), token.totalSupply());

        assertEq(token.totalSupply(), 10_000_000e18);

        assertEq(token.owner(), multisig);

        assertEq(multisigVault.owner(), multisig);

        assertFalse(multisigVault.paused());
    }
}
```

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `deploy()`: Deploy any necessary contracts. This example demonstrates the
    deployment of Vault and an ERC20 token. Once the contracts are deployed,
    they are added to the `Addresses` contract by calling `addAddress()`.
-   `run()`: Sets environment for running the proposal. It sets `addresses` and `primaryForkId`. `addresses` is address object
    containing addresses to be used in proposal that are fetched from `Addresses.json`. `primaryForkId` is the RPC URL or alias of the blockchain that will be used to simulate the proposal actions and broadcast if any contract deployment is required.
-   `build()`: Set the necessary actions for your proposal. In this example,
    ERC20 token is whitelisted on the Vault contract. The actions should be
    written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address that will call actions is passed into `buildModifier`, it is the multisig for this example.
-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This
    function performs a call to `simulateActions()` from the inherited
    `MultisigProposal` contract. Internally, `_simulateActions()` simulates a call to the [Multicall3](https://www.multicall3.com/) contract with the calldata generated from the actions set up in the build step.
-   `validate()`: This final step is crucial for validating the post-execution state. It ensures that the multisig is the new owner of Vault and token, the tokens were transferred to multisig and the token was whitelisted on the Vault contract


## Proposal simulation

First of all, please remove all addresses in `Addresses.json` before running through the tutorial. Now it's time to proceed with execution. There are two options available:

1. **Using `forge test`**: Details on this method can be found in the [integration-tests.md](../testing/integration-tests.md) section.
2. **Using `forge script`**: This is the chosen method for this tutorial.

## Running the Proposal with `forge script`

### Deploying a Gnosis Safe Multisig on Testnet

To kick off this tutorial, you'll need a Gnosis Safe Multisig contract set up on the testnet.

1. Go to [Gnosis Safe](https://app.safe.global/) and pick your preferred testnet
   (we're using Sepolia for this tutorial). Follow the on-screen instructions to
   generate a new Safe Account.

2. After setting up your Safe, you'll find the address in the details section of your Safe Account. Make sure to copy this address and keep it handy for later steps.

### Setting Up Your Deployer Address

The deployer address is the the one you'll use to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet.

We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool.

If you're missing a wallet in `~/.foundry/keystores/`, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

### Setting Up the Addresses JSON

Set up Addresses.json file and add the Gnosis Safe address and deployer address to it. The file should look like this:

```json
[
    {
        "addr": "YOUR_GNOSIS_SAFE_ADDRESS",
        "name": "DEV_MULTISIG",
        "chainId": 11155111,
        "isContract": true
    },
    {
        "addr": "YOUR_DEV_EOA",
        "name": "DEPLOYER_EOA",
        "chainId": 11155111,
        "isContract": false
    }
]
```

Ensure that the `DEV_MULTISIG` address corresponds to a valid Multisig Gnosis Safe contract. If this is not the case, the script will fail with the error: `Multisig address doesn't match Gnosis Safe contract bytecode`.

### Running the Proposal

```sh
forge script src/proposals/MultisigProposal_01.sol --account ${wallet_name} --broadcast --slow --sender ${wallet_address} -vvvv
```

Before you execute the proposal script, double-check that the ${wallet_name} and ${wallet_address} accurately match the wallet details saved in `~/.foundry/keystores/`. It's crucial to ensure ${wallet_address} is correctly listed as the deployer address in the Addresses.json file. If these don't align, the script execution will fail.

The script will output the following:

```sh
Multisig output:
== Logs ==
  

--------- Addresses added ---------
  {
          'addr': '0xF9C26968C2d4E1C2ADA13c6323be31c1067EBB7c', 
          'chainId': 11155111,
          'isContract': true ,
          'name': 'MULTISIG_VAULT'
},
  {
          'addr': '0x2A2A18A71d0eA4B97ebb18D3820cd3625C3A1465', 
          'chainId': 11155111,
          'isContract': true ,
          'name': 'MULTISIG_TOKEN'
}
  
---------------- Proposal Description ----------------
  Multisig proposal mock
  
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
  0x174dea7100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000260000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a14650000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a14650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044095ea7b3000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f9c26968c2d4e1c2ada13c6323be31c1067ebb7c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004447e7ef240000000000000000000000002a2a18a71d0ea4b97ebb18d3820cd3625c3a1465000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000
```

If a password was provide to the wallet, the script will prompt for the password before broadcasting the proposal.

A signer from the multisig address can check whether the calldata proposed on the multisig matches the calldata obtained from the call. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.

The proposal script will deploy the contracts in `deploy()` method and will generate actions calldata for each individual action along with calldata for the proposal. The proposal can be executed manually using the cast send along with the calldata generated above. 
