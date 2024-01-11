# Addresses

## Overview

he Addresses contract plays a pivotal role in managing and storing the addresses of deployed contracts. This functionality is essential for facilitating access to these contracts within proposal contracts and ensuring accurate record-keeping post-execution.

## Structure

Deployed contract addresses are registered along with their respective names and networks. This data is stored in an array within a JSON file, adhering to the following format:

```json
[
    {
        "addr": "0x3dd46846eed8D147841AE162C8425c08BD8E1b41",
        "name": "DEV_MULTISIG",
        "chainId": 1234
    },
    {
        "addr": "0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9",
        "name": "TEAM_MULTISIG",
        "chainId": 1234
    },
    {
        "addr": "0x1a9C8182C09F50C8318d769245beA52c32BE35BC",
        "name": "PROTOCOL_TIMELOCK",
        "chainId": 1234
    },
    {
        "addr": "0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f",
        "name": "TIMELOCK_PROPOSER",
        "chainId": 1234
    },
    {
        "addr": "0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f",
        "name": "TIMELOCK_EXECUTOR",
        "chainId": 123
    }
]
```

The system allows contracts with identical names as long as they are deployed on
different networks. However, duplicates on the same network are not
permitted. The `Addresses.sol` contract enforces this rule by reverting during
construction if such a duplicate is detected.

## Usage

### Adding

Addresses can be added to the object during a proposal or test by calling the
addAddress function with the name to be saved in storage and the address of the
contract to be stored with that name. Calling this function without a chain id will save the contract and name to the current chain id.

```solidity
addresses.addAddress("CONTRACT_NAME", contractAddress);
```

If the address needs to be added to a chain id that is not the current chain id, that address can still be added by calling the same function with an additional chain id parameter.

```solidity
addresses.addAddress("CONTRACT_NAME", contractAddress, chainId);
```

Both functions will revert with the name, address and chain id in human-readable format if the contract name already has an existing address stored.

Addresses can be added before the proposal runs by modifying the Addresses JSON file. After a successful deployment the getRecordedAddresses function will return all of the newly deployed addresses, and their respective names and chain id's.

### Updating

If an address is already stored, and the name stays the same, but the address changes during a proposal or test, the updateAddress function can be called with the new address for the name.

```solidity
addresses.changeAddress("CONTRACT_NAME", contractAddress);
```

If the address needs to be updated on a chain id that is not the current chain id, that address can still be updated by calling the same function with an additional chain id parameter.

```solidity
addresses.changeAddress("CONTRACT_NAME", contractAddress, chainId);
```

Both functions will revert if the address does not already have an address set or the address to be set is the same as the existing address.

After a proposal that changes the address, the getChangedAddresses function should be called. This will return all of the old addresses, new addresses, and their respective names and chain id's.

### Removing

An address can be removed from storage by removing its entry from the Addresses JSON file. This way, when the Address contract is constructed, the name and address will not be saved to storage. Addresses should not be removed during a governance proposal or test.
