# Timelock Proposal

## Overview

Following the addition of FPS to project dependencies, the next step is creating a Proposal contract. This example serves as a guide for drafting a proposal for Timelock contract.

## Proposal Contract

The `TimelockProposal_01` proposal is available in the [fps-example-repo](https://github.com/solidity-labs-io/fps-example-repo/blob/main/src/proposals/simple-vault-timelock/TimelockProposal_01.sol). This contract is used as a reference for this tutorial.

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

-   `build()`: Add actions to the proposal contract. In this example, an ERC20 token is whitelisted on the Vault contract. Then the timelock approves the token to be spent by the vault, and calls deposit on the vault. The actions should be written in solidity code and in the order they should be executed in the proposal. Any calls (except to the Addresses and Foundry Vm contract) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`; it is the timelock for this example. The `buildModifier` is a necessary modifier for the `build` function and will not work without it. For further reading, see the [build function](../overview/architecture/proposal-functions.md#build-function).

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

-   `run()`: Sets up the environment for running the proposal, and executes all proposal actions. This sets `addresses`, `primaryForkId`, and `timelock` and calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `sepolia` for running the proposal. Next, the `addresses` object is set by reading the JSON file. The timelock contract to test is set using `setTimelock`. This will be used to check onchain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

    ```solidity
    function run() public override {
        // Create and select the sepolia fork for proposal execution
        primaryForkId = vm.createFork("sepolia");
        vm.selectFork(primaryForkId);

        string memory addressesFolderPath = "./addresses";
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 11155111;
        // Set the addresses object by reading addresses from the json file.
        setAddresses(
            new Addresses(addressesFolderPath, chainIds)
        );

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

### Deploying a Timelock Controller on Testnet

Before executing the proposal, set up a Timelock Controller contract on the testnet. A script [DeployTimelock](https://github.com/solidity-labs-io/fps-example-repo/tree/main/script/DeployTimelock.s.sol) is provided to streamline this process.

Before running the script, add the `DEPLOYER_EOA` address to the `11155111.json` file.

```json
[
    {
        "addr": "0x<YOUR_DEV_ADDRESS>",
        "name": "DEPLOYER_EOA",
        "isContract": false
    }
]
```

After adding the address, execute the script:

```sh
forge script script/DeployTimelock.s.sol --broadcast --rpc-url
sepolia --slow --sender ${wallet_address} --account ${wallet_name} -vvv
```

Ensure that the ${wallet_name} and ${wallet_address} accurately correspond to the wallet details saved in `~/.foundry/keystores/`.

### Setting Up the Addresses JSON

Add the Timelock Controller address to the JSON file. The file should follow this structure:

```json
[
    {
        "addr": "0x<YOUR_TIMELOCK_ADDRESS>",
        "name": "PROTOCOL_TIMELOCK",
        "isContract": true
    },
    {
        "addr": "0x<YOUR_DEV_ADDRESS>",
        "name": "DEPLOYER_EOA",
        "isContract": false
    }
]
```

### Running the Proposal

```sh
forge script src/proposals/simple-vault-timelock/TimelockProposal_01.sol --account ${wallet_name} --broadcast --slow --sender ${wallet_address} -vvvv
```

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          "addr": "0x69A5DfCD97eF074108b480e369CecfD9335565A2",
          "isContract": true,
          "name": "TIMELOCK_VAULT"
},
  {
          "addr": "0x541234b61c081eaAE62c9EF52A633cD2aaf92A05",
          "isContract": true,
          "name": "TIMELOCK_TOKEN"
}

---------------- Proposal Description ----------------
  Timelock proposal mock

------------------ Proposal Actions ------------------
  1). calling TIMELOCK_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001 data.
  target: TIMELOCK_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x0ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001


  2). calling TIMELOCK_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 with 0 eth and 0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000 data.
  target: TIMELOCK_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05
payload
  0x095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a000000


  3). calling TIMELOCK_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2 with 0 eth and 0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000 data.
  target: TIMELOCK_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2
payload
  0x47e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a000000



----------------- Proposal Changes ---------------


 TIMELOCK_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2:

 State Changes:
  Slot: 0x0109a4c58357d68655b3b5dc2118952a94bd8ac20af5042c287646f3faf63d0e
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000000000001
  Slot: 0x570d2578c4c2f96ed37305ce1685ed898fe432030f7fac7156d302ec6426a582
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0x570d2578c4c2f96ed37305ce1685ed898fe432030f7fac7156d302ec6426a583
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000066b36550


 TIMELOCK_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05:

 State Changes:
  Slot: 0xe27288751d863b582c7b8b6e123cdcc6c4c2d47694a919c30174370281c9b73b
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000
  Slot: 0xe27288751d863b582c7b8b6e123cdcc6c4c2d47694a919c30174370281c9b73b
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0x5581b3a724040c4734d7106fa4393f167b0e7b9b13664999ef1d386d2af74db1
  -  0x000000000000000000000000000000000000000000084595161401484a000000
  +  0x0000000000000000000000000000000000000000000000000000000000000000
  Slot: 0xdbde422d34765d6fa450f050d95a7072ade5d1938cc2a6df4441c92d8c263663
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x000000000000000000000000000000000000000000084595161401484a000000


 PROTOCOL_TIMELOCK @0xFAb1fCA6DE9BEc87AD88cE70d1b5356aaf0f5E74:

 Transfers:
  Sent 10000000000000000000000000 TIMELOCK_TOKEN @0x541234b61c081eaAE62c9EF52A633cD2aaf92A05 to TIMELOCK_VAULT @0x69A5DfCD97eF074108b480e369CecfD9335565A2


------------------ Schedule Calldata ------------------
  0x8f2a0bb000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000000eff0dbf88af0664ed6d8db81251aaaeac77a977f015bb9bf3d34c91b1bf988a6000000000000000000000000000000000000000000000000000000000000003c000000000000000000000000000000000000000000000000000000000000000300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a0500000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000


------------------ Execute Calldata ------------------
  0xe38335e500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000000eff0dbf88af0664ed6d8db81251aaaeac77a977f015bb9bf3d34c91b1bf988a6000000000000000000000000000000000000000000000000000000000000000300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a0500000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a200000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a050000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044095ea7b300000000000000000000000069a5dfcd97ef074108b480e369cecfd9335565a2000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004447e7ef24000000000000000000000000541234b61c081eaae62c9ef52a633cd2aaf92a05000000000000000000000000000000000000000000084595161401484a00000000000000000000000000000000000000000000000000000000000000
```

It is crucial to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON files when proposal is run without the `DO_UPDATE_ADDRESS_JSON` flag set to true.

The proposal script will deploy the contracts in the `deploy()` method and will generate action calldata for each individual action, along with schedule and execute calldatas for the proposal. The proposal can be scheduled and executed manually using `cast send` along with the calldata generated above.
