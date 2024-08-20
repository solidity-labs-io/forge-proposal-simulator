# Addresses

## Overview

The Addresses contract plays an important role in managing and storing the addresses of deployed contracts and protocol EOAs. This functionality is essential for facilitating access to these contracts within proposal contracts and ensuring accurate record-keeping post-execution. Additionally, this contract contains important safety checks such as checking bytecode and providing error messages when non-existent addresses are queried.

## Structure

Deployed contract addresses are registered along with their respective names and networks. This data is stored in an array within a JSON file, adhering to the following format:

```json
[
    {
        "addr": "0x3dd46846eed8D147841AE162C8425c08BD8E1b41",
        "name": "DEV_MULTISIG",
        "chainId": 1234,
        "isContract": true
    },
    {
        "addr": "0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9",
        "name": "TEAM_MULTISIG",
        "chainId": 1234,
        "isContract": true
    },
    {
        "addr": "0x1a9C8182C09F50C8318d769245beA52c32BE35BC",
        "name": "PROTOCOL_TIMELOCK",
        "chainId": 1234,
        "isContract": true
    },
    {
        "addr": "0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f",
        "name": "DEPLOYER_EOA",
        "chainId": 123,
        "isContract": true
    }
]
```

FPS allows contracts with identical names as long as they are deployed on different networks. However, duplicates on the same network are not permitted. The `Addresses.sol` contract enforces this rule by reverting during construction if such a duplicate is detected. It also checks that the same address is not set under two different names on the same network.

## Functions

### Adding

Addresses can be added to the object during a proposal or test by calling the `addAddress` function with the name to be saved in storage, the address of the contract to be stored with that name and whether the address is a contract. Calling this function without a chain id will save the contract and name to the current chain id.

```solidity
addresses.addAddress("CONTRACT_NAME", contractAddress, isContract);
```

If the address needs to be added to a chain id that is not the current chain id, that address can still be added by calling the same function with an additional chain id parameter.

```solidity
addresses.addAddress("CONTRACT_NAME", contractAddress, chainId, isContract);
```

FPS has the following type checks implemented for the function `addAddress`:

-   Address must be unique for a given name and chain id.
-   Address must be non-zero.
-   Chain id must be non-zero.
-   Address must be a contract in the specified chain if `isContract` is set to `true`.
-   Address must not be a contract in the specified chain if `isContract` is set to `false`.

Addresses can be added before the proposal runs by modifying the Addresses JSON file. After a successful deployment, the `getRecordedAddresses` function will return all of the newly deployed addresses and their respective names and chain id's.

### Updating

If an address is already stored, and the name stays the same, but the address changes during a proposal or test, the `changeAddress` function can be called with the new address for the name.

```solidity
addresses.changeAddress("CONTRACT_NAME", contractAddress, isContract);
```

If the address needs to be updated on a chain id that is not the current chain id, that address can still be updated by calling the same function with an additional chain id parameter.

```solidity
addresses.changeAddress("CONTRACT_NAME", contractAddress, chainId);
```

FPS has the following type checks implemented for the function `changeAddress`:

-   Address must be unique for a given name and chain id.
-   Address must be non-zero.
-   Chain id must be non-zero.
-   Address must be a contract in the specified chain if `isContract` is set to `true`.
-   Address must not be a contract in the specified chain if `isContract` is set to `false`.
-   Address must be different from the existing address.
-   An address for the specified name must already exist.

After a proposal that changes the address, the `getChangedAddresses` function should be called. This will return all of the old addresses, new addresses, and their respective names and chain id's.

### Removing

An address can be removed from storage by removing its entry from the Addresses JSON file. This way, when the Address contract is constructed, the name and address will not be saved to storage. Addresses should not be removed during a governance proposal or test.

### Retrieving

Addresses can be retrieved by calling the `getAddress` function with the name of the contract.

```solidity
addresses.getAddress("CONTRACT_NAME");
```

If the address needs to be retrieved from a chain id that is not the current chain id, that address can still be retrieved by calling the same function with an additional chain id parameter.

```solidity
addresses.getAddress("CONTRACT_NAME", chainId);
```

### Retrieving Recorded Addresses

Addresses added during the proposals executions can be retrieved by calling the `getRecordedAddresses` function.

```solidity
addresses.getRecordedAddresses();
```

### Retrieving Changed Addresses

Addresses changed during the proposals executions can be retrieved by calling the `getChangedAddresses` function.

```solidity
addresses.getChangedAddresses();
```

### Print Added and Changed Addressses

Addresses that are changed or newly added during the proposal's execution can be retrieved by calling the `printJSONChanges` method. It prints the changes in JSON format, making it easy for users to add them to `Addresses.json`.

```solidity
addresses.printJSONChanges();
```

### Address exists

The `isAddressSet` function checks if an address exists in the Addresses contract storage.

```solidity
addresses.isAddressSet("CONTRACT_NAME");
```

```solidity
addresses.isAddressSet("CONTRACT_NAME", chainId);
```

### Address is a contract

The `isAddressContract` function determines whether an address on the execution chain represents a contract. This is useful for distinguishing between contract and non-contract addresses, helping to avoid runtime errors when attempting to interact with non-existent contracts or contracts not deployed on the current chain.

```solidity
addresses.isAddressContract("CONTRACT_NAME");
```

### Update addresses file

The `updateJson` function updates the `Addresses.json` file with the newly added and changed addresses. This is helpful as a user doesn't need to update the file manually after the proposal run.

```solidity
addresses.updateJson();
```

## Usage

When writing a proposal, set the `addresses` object using the `setAddresses` method. Ensure the correct path for `Addresses.json` file is passed inside the constructor while creating the `addresses` object. Use the `addresses` object to add, update, retrieve, and remove addresses.

```solidity
pragma solidity ^0.8.0;

import { MultisigProposal } from "@forge-proposal-simulator/proposals/MultisigProposal.sol";

import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { MyContract } from "@path/to/MyContract.sol";

contract PROPOSAL_01 is MultisigProposal {
    string private constant ADDRESSES_PATH = "./addresses/Addresses.json";

    function deploy() public override {
        if (!addresses.isAddressSet("CONTRACT_NAME")) {
            /// Deploy a new contract
            MyContract myContract = new MyContract();

            /// Interact with the Addresses object, adding the new contract address
            addresses.addAddress("CONTRACT_NAME", address(myContract), true);
        }
    }

    function run() {
        // Set addresses object for the proposal
        setAddresses(new Addresses(ADDRESSES_PATH));

        super.run();
    }
}
```
