# ENS OZ Governor Proposal

## Overview

This example on mainnet demonstrates FPS being utilized to simulate proposals for the ENS Governor on mainnet. The proposal involves setting up a new DNSSEC on the ENS root. It entails deploying a new DNSSEC contract named `UPGRADE_DNSSEC_SUPPORT`. Subsequently, the timelock sets the newly deployed DNSSEC contract as the controller for the ENS Root.

The contract for this proposal is located in the [mocks folder](../../mocks/MockOZGovernorProposal.sol).

Let's review each of the overridden functions:

-   `name()`: Specifies the name of the proposal.

    ```solidity
    function name() public pure override returns (string memory) {
        return "UPGRADE_DNSSEC_SUPPORT";
    }
    ```

-   `description()`: Provides a detailed description of the proposal.

    ```solidity
    function description() public pure override returns (string memory) {
        return
            "Call setController on the Root contract at root.ens.eth, passing in the address of the new DNS registrar";
    }
    ```

-   `deploy()`: Deploys any necessary contracts. This example demonstrates the deployment of a new `dnsSec` contract (only a mock for this proposal). Once the contracts are deployed, they are added to the `Addresses` contract by calling `addAddress()`.

    ```solidity
    function deploy() public override {
        // Deploy a mock upgrade contract to set controller if not already deployed
        if (!addresses.isAddressSet("ENS_DNSSEC")) {
            // In a real case, this function would be responsible for
            // deploying the DNSSEC contract instead of using a mock
            address dnsSec = address(new MockUpgrade());

            addresses.addAddress("ENS_DNSSEC", dnsSec, true);
        }
    }
    ```

    Since these changes do not persist from runs themselves, after the contracts are deployed, the user must update the Addresses.json file with the newly deployed contract addresses.

-   `build()`: Add actions to the proposal contract. In this example, the newly deployed `dnsSec` contract is set as the controller for the root contract. Any calls (except to the Addresses object) will be recorded and stored as actions to execute in the run function. The `caller` address that will call actions is passed into `buildModifier`. In this example, it is the OZ Governor's timelock. The `buildModifier` is a necessary modifier for the `build` function and will not function without it. For further reading, see the [build function](../overview/architecture/proposal-functions.md#build-function).

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

        // Set controller to newly deployed dnsSec contract
        control.setController(dnsSec, true);
    }
    ```

-   `run()`: Sets up the environment for running the proposal, and executes all proposal actions. This sets `addresses`, `primaryForkId`, and `governor`, and then calls `super.run()` to run the entire proposal. In this example, `primaryForkId` is set to `mainnet`, selecting the fork for running the proposal. Next, the `addresses` object is set by reading the `addresses.json` file. The OZ Governor contract to test is set using `setGovernor`. This will be used to check onchain calldata and simulate the proposal. For further reading, see the [run function](../overview/architecture/proposal-functions.md#run-function).

    ```solidity
    function run() public override {
        // Create and select the mainnet fork for proposal execution.
        setPrimaryForkId(vm.createFork("mainnet"));
        vm.selectFork(primaryForkId);

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;
        // Set the addresses object by reading addresses from the JSON file.
        setAddresses(
            new Addresses(
                vm.envOr("ADDRESSES_PATH", string("./addresses")), chainIds
            )
        );

        // Set Governor Bravo. This address is used for proposal simulation and checking the on-chain proposal state.
        setGovernor(addresses.getAddress("ENS_GOVERNOR"));

        // Call the run function of the parent contract 'Proposal.sol'.
        super.run();
    }
    ```

-   `validate()`: This final step validates the system in its post-execution state. It ensures that the dnsSec contract is set as the controller for the root contract.

    ```solidity
    function validate() public view override {
        // Get ENS root address
        IControllable control = IControllable(addresses.getAddress("ENS_ROOT"));

        // Get deployed dnsSec address
        address dnsSec = addresses.getAddress("ENS_DNSSEC");

        // Ensure dnsSec is set as the controller for the ENS root contract
        assertEq(control.controllers(dnsSec), true);
    }
    ```

## Running the Proposal

```sh
forge script mocks/MockOZGovernorProposal.sol:MockOZGovernorProposal --fork-url mainnet
```

All required addresses should be in the Addresses.json file, including the `DEPLOYER_EOA` address, which will deploy the new contracts. If these do not align, the script execution will fail.

The script will output the following:

```sh
== Logs ==


--------- Addresses added ---------
  {
          "addr": "0x714CB817EfD08fEe91558b07A924a87C3587F3C1",
          "isContract": true,
          "name": "ENS_DNSSEC"
}

---------------- Proposal Description ----------------
  Call setController on the Root contract at root.ens.eth, passing in the address of the new DNS registrar

------------------ Proposal Actions ------------------
  1). calling ENS_ROOT @0xaB528d626EC275E3faD363fF1393A41F581c5897 with 0 eth and 0xe0dba60f000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000001 data.
  target: ENS_ROOT @0xaB528d626EC275E3faD363fF1393A41F581c5897
payload
  0xe0dba60f000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c10000000000000000000000000000000000000000000000000000000000000001



----------------- Proposal Changes ---------------


 ENS_ROOT @0xaB528d626EC275E3faD363fF1393A41F581c5897:

 State Changes:
  Slot: 0x683b779d654146db8352b5203c98de0bc792fdb59471541d9a885b4f9933a736
  -  0x0000000000000000000000000000000000000000000000000000000000000000
  +  0x0000000000000000000000000000000000000000000000000000000000000001


------------------ Proposal Calldata ------------------
  0x7d5e81e2000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001c00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000ab528d626ec275e3fad363ff1393a41f581c589700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000044e0dba60f000000000000000000000000714cb817efd08fee91558b07a924a87c3587f3c1000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006843616c6c20736574436f6e74726f6c6c6572206f6e2074686520526f6f7420636f6e747261637420617420726f6f742e656e732e6574682c2070617373696e6720696e207468652061646472657373206f6620746865206e657720444e5320726567697374726172000000000000000000000000000000000000000000000000
```
