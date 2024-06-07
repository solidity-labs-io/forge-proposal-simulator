# Multisig Proposal

## Overview

Following the addition of FPS to project dependencies, the subsequent step involves creating the initial Proposal contract. This example serves as a guide for drafting a proposal for Multisig contract.

## Proposal contract

The `MultisigProposal_01` proposal is available in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-multisig/MultisigProposal_01.sol). This contract is used as a reference for this tutorial.

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "MULTISIG_MOCK";
    }
    ```

-   `description()`: Provide a detailed description of your proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return "Multisig proposal mock";
    }
    ```

-   `deploy()`: Deploy any necessary contracts. This example demonstrates the deployment of Vault and an ERC20 token. Once the contracts are deployed, they are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // get multisig address
        address multisig = addresses.getAddress("DEV_MULTISIG");

        // Deploy vault address if not already deployed and transfer ownership to multisig.
        if (!addresses.isAddressSet("MULTISIG_VAULT")) {
            Vault multisigVault = new Vault();

            addresses.addAddress(
                "MULTISIG_VAULT",
                address(multisigVault),
                true
            );
            multisigVault.transferOwnership(multisig);
        }

        // Deploy token address if not already deployed, transfer ownership to multisig
        // and transfer all initial minted tokens from deployer to multisig.
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
    ```

    Since these changes do not persist from runs themselves, after the contracts are deployed, the user must update the Addresses.json file with the newly deployed contract addresses.

-   `build()`: Add actions to the proposal contract. [See build function](../overview/architecture/proposal-functions.md#build-function). In this example, an ERC20 token is whitelisted on the Vault contract. Then multisig approves token for vault and deposits all tokens into the vault. The actions should be written in solidity code and in the order they should be executed. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`, it is the multisig for this example. `buildModifier` is necessary modifier for `build` function and will not work without it.

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("DEV_MULTISIG"))
    {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get multisig address
        address multisig = addresses.getAddress("DEV_MULTISIG");

        // Get vault address
        address multisigVault = addresses.getAddress("MULTISIG_VAULT");

        // Get token address
        address token = addresses.getAddress("MULTISIG_TOKEN");

        // Get multisig's token balance
        uint256 balance = Token(token).balanceOf(address(multisig));

        /// CALLS -- mutative and recorded

        // Whitelists the deployed token on the deployed vault.
        Vault(multisigVault).whitelistToken(token, true);

        // Approve the token for the vault.
        Token(token).approve(multisigVault, balance);

        // Deposit all tokens into the vault.
        Vault(multisigVault).deposit(token, balance);
    }
    ```

-   `run()`: Sets up the environment for running the proposal. [See run function](../overview/architecture/proposal-functions.md#run-function). This sets `addresses`, `primaryForkId` and calls `super.run()` run the entire proposal. In this example, `primaryForkId` is set to `sepolia` and selecting the fork for running proposal. Next the `addresses` object is set by reading `addresses.json` file.

    ```solidity
    function run() public override {
        // Create and select sepolia fork for proposal execution
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        // Set addresses object reading addresses from json file.
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("addresses/Addresses.json"))
            )
        );

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This function performs a call to `_simulateActions()` from the inherited `MultisigProposal` contract. Internally, `_simulateActions()` simulates a call to the [Multicall3](https://www.multicall3.com/) contract with the calldata generated from the actions set up in the build step.

    ```solidity
    function simulate() public override {
        // Get multisig address
        address multisig = addresses.getAddress("DEV_MULTISIG");

        // multisig is the caller for all the proposal actions
        _simulateActions(multisig);
    }
    ```

-   `validate()`: This final step validates the system in its post-execution state. It ensures that the multisig is the new owner of Vault and token, the tokens were transferred to the multisig, and the token was whitelisted on the Vault contract

    ```solidity
    function validate() public override {
        // Get vault address
        Vault multisigVault = Vault(addresses.getAddress("MULTISIG_VAULT"));

        // Get token address
        Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));

        // Get multisig address
        address multisig = addresses.getAddress("DEV_MULTISIG");

        // Ensure token total supply is 10 million
        assertEq(token.totalSupply(), 10_000_000e18);

        // Ensure multisig is owner of deployed token.
        assertEq(token.owner(), multisig);

        // Ensure multisig is owner of deployed vault
        assertEq(multisigVault.owner(), multisig);

        // Ensure vault is not paused
        assertFalse(multisigVault.paused());

        // Ensure token is whitelisted on vault
        assertTrue(multisigVault.tokenWhitelist(address(token)));

        // Get vault's token balance
        uint256 balance = token.balanceOf(address(multisigVault));

        // Get multisig deposits in vault
        (uint256 amount, ) = multisigVault.deposits(address(token), multisig);

        // Ensure multisig deposit is same as vault's token balance
        assertEq(amount, balance);

        // Ensure all minted tokens are deposited into the vault
        assertEq(token.balanceOf(address(multisigVault)), token.totalSupply());
    }
    ```

## Proposal simulation

### Deploying a Gnosis Safe Multisig on Testnet

To kick off this tutorial, a Gnosis Safe Multisig contract is needed to be set up on the testnet.

1. Go to [Gnosis Safe](https://app.safe.global/) and pick your preferred testnet (Sepolia is used for this tutorial). Follow the on-screen instructions to generate a new Safe Account.

2. After setting up of Safe, address can be found in the details section of the Safe Account. Make sure to copy this address and keep it handy for later steps.

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
forge script src/proposals/simple-vault-multisig/MultisigProposal_01.sol --account ${wallet_name} --broadcast --slow --sender ${wallet_address} -vvvv
```

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

A signer from the multisig address can check whether the calldata proposed on the multisig matches the calldata obtained from the call. It is crucial to note that two new addresses have been added to the Addresses.sol storage. These addresses are not included in the JSON file and must be added manually for accuracy.

The proposal script will deploy the contracts in the `deploy()` method and will generate action calldata for each individual action along with calldata for the proposal. The proposal can be executed manually using the cast send command along with the calldata generated above.
