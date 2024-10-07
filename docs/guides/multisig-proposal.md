# Multisig Proposal

## Overview

Following the addition of FPS to project dependencies, the next step is creating a Proposal contract. This example serves as a guide for drafting a proposal for a Multisig contract.

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

-   `build()`: Add actions to the proposal contract. In this example, an ERC20 token is whitelisted on the Vault contract. Then the multisig approves the token to be spent by the vault, and calls deposit on the vault. The actions should be written in solidity code and in the order they should be executed in the proposal. Any calls (except to the Addresses and Foundry Vm contract) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`, it is the multisig for this example. The `buildModifier` is necessary modifier for `build` function and will not work without it. For further reading, see the [build function](../overview/architecture/proposal-functions.md#build-function).

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

-   `run()`: Sets up the environment for running the proposal, and executes all proposal actions. This sets `addresses`, `primaryForkId` and calls `super.run()` run the entire proposal. In this example, `primaryForkId` is set to `sepolia` and selecting the fork for running proposal. Next the `addresses` object is set by reading from the JSON file. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

    ```solidity
    function run() public override {
        // Create and select sepolia fork for proposal execution
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        string memory addressesFolderPath = "./addresses";
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        // Set addresses object reading addresses from json file.
        setAddresses(
            new Addresses(addressesFolderPath, chainIds)
        );

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `simulate()`: Execute the proposal actions outlined in the `build()` step. This function performs a call to `_simulateActions()` from the inherited `MultisigProposal` contract. Internally, `_simulateActions()` simulates a call to the [Multicall3](https://www.multicall3.com/) contract with the calldata generated from the actions set up in the build step. Multicall contract is used to execute all of the actions together in a single safe action. This is done by batching all the build actions together using the `aggregate3Value` multicall3 function. The single safe action is a delegate call to the multicall3 contract as the caller for all the batched actions should be the multisig contract and not the multicall3 contract.

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

2. After setting up the Safe, its address can be found in the details section of the Safe Account. Make sure to copy this address and keep it handy for later steps.

### Setting Up the Addresses JSON

Set up `11155111.json` file and add the Gnosis Safe address and deployer address to it. The file should follow this structure:

```json
[
    {
        "addr": "0x<YOUR_GNOSIS_SAFE_ADDRESS>",
        "name": "DEV_MULTISIG",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_DEV_EOA",
        "name": "DEPLOYER_EOA",
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
== Logs ==


--------- Addresses added ---------
  {
          "addr": "0x69A5DfCD97eF074108b480e369CecfD9335565A2",
          "isContract": true,
          "name": "MULTISIG_VAULT"
},
  {
          "addr": "0x541234b61c081eaAE62c9EF52A633cD2aaf92A05",
          "isContract": true,
          "name": "MULTISIG_TOKEN"
}

---------------- Proposal Description ----------------
  Multisig proposal mock

------------------ Proposal Actions ------------------
  1). calling MULTISIG_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001 data.
  target: MULTISIG_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001


  2). calling MULTISIG_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 with 0 eth and 0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000 data.
  target: MULTISIG_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05
payload
  0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000


  3). calling MULTISIG_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000 data.
  target: MULTISIG_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000



----------------- Proposal Changes ---------------


 MULTISIG_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2:

 State Changes:
  Slot: 0x0109a4c58357d68655b3b5dc2118952a94bd8ac20af5042c287646f3faf63d0e
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000000000001
  Slot: 0x5c89714d3d4b91fc2765de3ae9d78fa63c87d45455b314a1983c2aa9091d790a
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0x5c89714d3d4b91fc2765de3ae9d78fa63c87d45455b314a1983c2aa9091d790b
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000066b363b8


 MULTISIG_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05:

 State Changes:
  Slot: 0x718dfd4f53e9042ef07e2076db0bd95307c2640e8a375658915485d37fe05299
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0x718dfd4f53e9042ef07e2076db0bd95307c2640e8a375658915485d37fe05299
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0x233078cbccee5fe4b8e098848f55eedd08e0fd43b7ddea16843770de9714b0bc
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0xdbde422d34765d6fa450f050d95a7072ade5d1938cc2a6df4441c92d8c263663
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000


 DEV_MULTISIG @0x1c1A8861139C0126176bD1B0d01Bbf5E4c99591b:

 Transfers:
  Sent 10000000000000000000000000 MULTISIG_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 to MULTISIG_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2


------------------ Proposal Calldata ------------------
  0x174dea710000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000026000000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000044095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004447e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000
```

A signer from the multisig address can check whether the calldata proposed on the multisig matches the calldata obtained from the call. It is crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON files when proposal is run without the `DO_UPDATE_ADDRESS_JSON` flag set to true.

The proposal script will deploy the contracts in the `deploy()` method and will generate action calldata for each individual action along with calldata for the proposal. The proposal can be executed manually using `cast send` command along with the calldata generated above.
