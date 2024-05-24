# ENS GOVERNOR OZ Proposal

## Overview

This is an mainnet example of FPS where FPS is used to simulate proposals for ENS governor on L1. This example sets new DNSSEC on ens root on L1. This proposal deploys new DNSSEC contract `UPGRADE_DNSSEC_SUPPORT`. Then timelock sets new deployed DNSSEC contract as controller for ENS Root.

The following contract is present in the [mocks folder](../../mocks/MockOZGovernorProposal.sol).

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
    ```solidity
    function name() public pure override returns (string memory) {
        return "UPGRADE_DNSSEC_SUPPORT";
    }
    ```
-   `description()`: Provide a detailed description of your proposal.
    ```solidity
    function description() public pure override returns (string memory) {
        return
            "Call setController on the Root contract at root.ens.eth, passing in the address of the new DNS registrar";
    }
    ```
-   `build()`: Set the necessary actions for your proposal. [Refer](../overview/architecture/proposal-functions.md#build-function). In this example, newly deployed `dnsSec` contract is set as controller for root contract. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. `caller` address that will call actions is passed into `buildModifier`, it is the oz governor's timelock for this example. `buildModifier` is necessary modifier for `build` function and will not work without it.

    ```solidity
    function build()
        public
        override
        buildModifier(addresses.getAddress("ENS_TIMELOCK"))
    {
        /// STATICCALL -- non-mutative and hence not recorded for the run stage

        // Get ENS root address
        IControllable control = IControllable(addresses.getAddress("ENS_ROOT"));

        // Get deployed dnsSec address
        address dnsSec = addresses.getAddress("ENS_DNSSEC");

        /// CALLS -- mutative and recorded

        // Set controller to new deployed dnsSec contract
        control.setController(dnsSec, true);
    }
    ```

-   `deploy()`: Deploy any necessary contracts. This example demonstrates the deployment of new `dnsSec` contract (only a mock for this proposal). Once the contracts are deployed, they are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // deploy a mock upgrade contract to set controller if not already deployed
        if (!addresses.isAddressSet("ENS_DNSSEC")) {
            // In a real case, this function would be responsable for
            // deployig the DNSSEC contract instead of using a mock
            address dnsSec = address(new MockUpgrade());

            addresses.addAddress("ENS_DNSSEC", dnsSec, true);
        }
    }
    ```

-   `validate()`: This final step validates the system in its post-execution state. It ensures that dnsSec contract is set as controller for root contract.

    ```solidity
    function validate() public view override {
        // Get ENS root address
        IControllable control = IControllable(addresses.getAddress("ENS_ROOT"));

        // Get deployed dnsSec address
        address dnsSec = addresses.getAddress("ENS_DNSSEC");

        // Ensure dnsSec is set as controller for ENS root contract
        assertEq(control.controllers(dnsSec), true);
    }
    ```

-   `run()`: Sets environment for running the proposal. [Refer](../overview/architecture/proposal-functions.md#run-function). It sets `addresses`, `primaryForkId` and `governor` and calls `super.run()` to run proposal lifecycle. In this function, `primaryForkId` is set to `mainnet` and selecting the fork for running proposal. Next `addresses` object is set by reading `addresses.json` file. `addresses` contract state is persisted accross forks using `vm.makePersistent()`. governor oz is set using `setGovernor` that will be used to check onchain calldata and simulate the proposal.

    ```solidity
    function run() public override {
        // Create and select mainnet fork for proposal execution.
        setPrimaryForkId(vm.createFork("mainnet"));
        vm.selectFork(primaryForkId);

        // Set addresses object reading addresses from json file.
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("./addresses/Addresses.json"))
            )
        );

        // Make 'addresses' state persist across selected fork.
        vm.makePersistent(address(addresses));

        // Set oz governor. This address is used for proposal simulation and check on
        // chain proposal state.
        setGovernor(addresses.getAddress("ENS_GOVERNOR"));

        // Call the run function of parent contract 'Proposal.sol'.
        super.run();
    }
    ```

## Setting Up Your Deployer Address

The deployer address is the one used to broadcast the transactions deploying the proposal contracts. Ensure your deployer address has enough funds from the faucet to cover deployment costs on the testnet. We prioritize security when it comes to private key management. To avoid storing the private key as an environment variable, we use Foundry's cast tool. Ensure cast address is same as Deployer address.

If you're missing a wallet in `~/.foundry/keystores/`, create one by executing:

```sh
cast wallet import ${wallet_name} --interactive
```

## Running the Proposal

```sh
forge script mocks/MockOZGovernorProposal.sol:MockOZGovernorProposal --fork-url mainnet
```

All required addresses should be in the Addresses.json file including `DEPLOYER_EOA` address which will deploy the new contracts. If these don't align, the script execution will fail.

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          'addr': '0x714CB817EfD08fEe91558b07A924a87C3587F3C1',
          'chainId': 1,
          'isContract': true ,
          'name': 'ENS_DNSSEC'
}

---------------- Proposal Description ----------------
  Call setController on the Root contract at root.ens.eth, passing in the address of the new DNS registrar

------------------ Proposal Actions ------------------
  1). calling 0xaB528d626EC275E3faD363fF1393A41F581c5897 with 0 eth and 0xe0dba60f000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000001 data.
  target: 0xaB528d626EC275E3faD363fF1393A41F581c5897
payload
  0xe0dba60f000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000001




------------------ Proposal Calldata ------------------
  0x7d5e81e2000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000ab528d626ec275e3fad363ff1393a41f581c589700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000044e0dba60f000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c1000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006843616c6c20736574436f6e74726f6c6c6572206f6e2074686520526f6f7420636f6e747261637420617420726f6f742e656e732e6574682c2070617373696e6720696e207468652061646472657373206f6620746865206e657720444e5320726567697374726172000000000000000000000000000000000000000000000000
```
