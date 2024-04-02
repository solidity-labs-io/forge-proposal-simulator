# Multisig Proposal

After adding FPS into project dependencies, the next step is the creation of the first Proposal contract. This example provides guidance on writing a proposal for deploying new instances of `Vault.sol` and `MockToken`. These contracts are located in the [guides section](./introduction.md#example-contracts). The proposal includes the transfer of ownership of both contracts to a multisig wallet, along with the whitelisting of the token and minting of tokens to the multisig.

Proposal files are located in the `proposals` folder. Create a new file called `MULTISIG_01.sol` and add the following code:

```solidity
pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Proposal} from "@proposals/Proposal.sol";

// MULTISIG_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the multisig address
// Finally the proposal whitelist the ERC20 token in the Vault contract
contract MULTISIG_01 is MultisigProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor()
        Proposal(
            ADDRESSES_PATH,
            "DEV_MULTISIG"
        )
    {}

    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "MULTISIG_01";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Deploy Vault contract";
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

    /// @notice proposal action steps:
    /// 1. Transfers vault ownership to dev multisig.
    /// 2. Transfer token ownership to dev multisig.
    /// 3. Transfers all tokens to dev multisig.
    function _afterDeploy() internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(devMultisig);
        token.transferOwnership(devMultisig);
        // Make sure that DEPLOYER is the address you specify in the --sender flag
        token.transfer(devMultisig, token.balanceOf(addresses.getAddress("DEPLOYER")));
    }

    /// @notice Sets up actions for the proposal, in this case, setting the MockToken to active.
    function _build() internal override {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALLS -- mutative and recorded
        Vault(timelockVault).whitelistToken(token, true);
    }

    /// @notice Executes the proposal actions.
    function _run() internal override {
        /// Call parent _run function to check if there are actions to execute
        super._run();

        address multisig = addresses.getAddress("DEV_MULTISIG");

        /// CALLS -- mutative and recorded
        _simulateActions(multisig);
    }

    /// @notice Validates the post-execution state.
    function _validate() internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        assertEq(timelockVault.owner(), devMultisig);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), devMultisig);
        assertEq(token.balanceOf(devMultisig), token.totalSupply());
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
    ERC20 token is whitelisted on the Vault contract. 
-   `_run()`: Execute the proposal actions outlined in the `_build()` step. This
    function performs a call to `simulateActions()` from the inherited
    `MultisigProposal` contract. Internally, `_simulateActions()` simulates a call to the [Multicall3](https://www.multicall3.com/) contract with the calldata generated from the actions set up in the build step.
-   `_validate()`: This final step is crucial for validating the post-execution state. It ensures that the multisig is the new owner of Vault and token, the tokens were transferred to multisig and the token was whitelisted on the Vault contract

Constructor parameters are passed to the `Proposal` contract. The
`ADDRESSES_PATH` is the path to the `Addresses.json` file, and `DEV_MULTISIG` is
the name of the address that will be used to execute the proposal actions.

With the first proposal contract prepared, it's time to proceed with execution. There are two options available:

1. **Using `forge test`**: Details on this method can be found in the [integration-tests.md](../testing/integration-tests.md "mention") section.
2. **Using `forge script`**: This is the chosen method for this scenario.

## Running the Proposal with `forge script`

### Get the Gnosis Safe Multisig Address

In order to complete this tutorial, it's necessary to have a Gnosis Safe
Multisig contract deployed on any testnet. We will use Sepolia for this
tutorial. 

If you want to deploy a new Gnosis Safe contract, you can go to
https://app.safe.global/, select the desired network, and follow the steps to
create a new Safe Account.

Once the Safe Account is created, you can find the address in the Safe Account
details. Copy the address and save it for later use.

### Set up the deployer address

The deployer is the address that will be used to broadcast the proposal contracts deployments. 
Make sure to have enough faucet funds in the deployer address to cover the deployment costs.

We leverage Foundry `cast` to keep private key management secure. 
We don't save private key in the environment variable.

If you don't have a wallet stored in `~/.foundry/keystores/`, you can create one by running the following command:

```sh
cast wallet import ${wallet_name }--interactive
```

### Set up the Addresses JSON

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
        "addr": "YOUR_DEPLOYER_EOA",
        "name": "DEPLOYER",
        "chainId": 11155111,
        "isContract": false
    }
]
```

Ensure that the `DEV_MULTISIG` address corresponds to a valid Multisig Gnosis Safe contract. If this is not the case, the script will fail with the error: `Multisig address doesn't match Gnosis Safe contract bytecode`.

### Run the proposal

```sh
forge script examples/multisig/MULTISIG_01.sol --account ${wallet_name} --broadcast --fork-url sepolia --slow --sender ${wallet_address} -vvvv
```

Before running the proposal, make sure that ${wallet_name} and ${wallet_address}
corresponds to the wallet saved in `~/.foundry/keystores/` and that
${wallet_address} is the deployer address set in the `Addresses.json` file, otherwise the script will fail.

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
  Deploy Vault contract
  

------------------ Proposal Actions ------------------
  1). calling 0x61a7a6f1553cbb39c87959623bb23833838406d7 with 0 eth and 0ffb1d8b0000000000000000000000007e1bf35e2b30ae6b62b59a93c49f9cf32b2739310000000000000000000000000000000000000000000000000000000000000001 data.
  target: 0x61A7A6F1553cbB39c87959623bb23833838406D7
payload
  0x0ffb1d8b0000000000000000000000007e1bf35e2b30ae6b62b59a93c49f9cf32b2739310000000000000000000000000000000000000000000000000000000000000001
  

  

------------------ Proposal Calldata ------------------
  0x252dba4200000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000061a7a6f1553cbb39c87959623bb23833838406d7000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000007e1bf35e2b30ae6b62b59a93c49f9cf32b273931000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000
```

If a password was provide to the wallet, the script will prompt for the password before broadcasting the proposal.

A signer from the multisig address can check whether the calldata proposed on the multisig matches the calldata obtained from the call. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.
