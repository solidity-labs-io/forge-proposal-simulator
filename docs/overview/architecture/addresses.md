# Addresses

## Overview

The Addresses contract plays a pivotal role in managing and storing the addresses of deployed contracts. This functionality is essential for facilitating access to these contracts within proposal contracts and ensuring accurate record-keeping post-execution.

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

FPS allows contracts with identical names as long as they are deployed on
different networks. However, duplicates on the same network are not
permitted. The `Addresses.sol` contract enforces this rule by reverting during
construction if such a duplicate is detected.

## Deployment

Usually `Addresses.json` will be deployed as part of the Proposal deployment process. However, if you need to deploy it separately, you can do so by running:

```solidity
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import { Addresses } from "@addresses/Addresses.sol";

contract DeployAddresses is Script {
    Addresses addresses;

    function run() public virtual {
        string memory addressesPath = "./addresses/Addresses.json";
        addresses = new Addresses(addressesPath);
    }
}
```

and then running:

```bash
forge script script/path/to/DeployAddresses.s.sol
```

## Usage

### Adding

Addresses can be added to the object during a proposal or test by calling the
`addAddress` function with the name to be saved in storage and the address of the
contract to be stored with that name. Calling this function without a chain id will save the contract and name to the current chain id.

```solidity
addresses.addAddress("CONTRACT_NAME", contractAddress);
```

If the address needs to be added to a chain id that is not the current chain id, that address can still be added by calling the same function with an additional chain id parameter.

```solidity
addresses.addAddress("CONTRACT_NAME", contractAddress, chainId);
```

Both functions will revert with the name, address and chain id in human-readable format if the contract name already has an existing address stored.

Addresses can be added before the proposal runs by modifying the Addresses JSON file. After a successful deployment the `getRecordedAddresses` function will return all of the newly deployed addresses, and their respective names and chain id's.

### Updating

If an address is already stored, and the name stays the same, but the address changes during a proposal or test, the `changeAddress` function can be called with the new address for the name.

```solidity
addresses.changeAddress("CONTRACT_NAME", contractAddress);
```

If the address needs to be updated on a chain id that is not the current chain id, that address can still be updated by calling the same function with an additional chain id parameter.

```solidity
addresses.changeAddress("CONTRACT_NAME", contractAddress, chainId);
```

Both functions will revert if the address does not already have an address set or the address to be set is the same as the existing address.

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

### Retrieving All

All addresses can be retrieved by calling the `getRecordedAddresses` function.

```solidity
addresses.getRecordedAddresses();
```

To retrieve all changed addresses, the `getChangedAddresses` function should be called.

```solidity
addresses.getChangedAddresses();
```

### Using with Proposals

All proposal [internal functions](./internal-functions.md) receive a `Addresses` instance as the
first paramater. You can then use the `addresses` variable to add, update, retrieve, and remove addresses.

```solidity
pragma solidity ^0.8.0;

import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { MultisigProposal } from "@forge-proposal-simulator/proposals/MultisigProposal.sol";
import { MyContract } from "@path/to/MyContract.sol";

contract PROPOSAL_01 is MultisigProposal {
    function _deploy(Addresses addresses, address) internal override {
        // Deploy a new contract
        MyContract myContract = new MyContract();

        // Interact with the Addresses object, adding the new contract address
        addresses.addAddress("CONTRACT_NAME", address(myContract));
    }
}
```

### Using with Scripts

When writing a script, you must pass the addresses path to the
`ScriptSuite.s.sol` constructor.

```solidity
pragma solidity ^0.8.0;

import { ScriptSuite } from "@forge-proposal-simulator/ScriptSuite.s.sol";
import { PROPOSAL_01 } from "/path/to/PROPOSAL_01.sol";

contract ProposalScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor() ScriptSuite(ADDRESSES_PATH, new PROPOSAL_01()) {}

    function run() public virtual override {
        // Addresses object is available here
        addresses.getAddress("CONTRACT_NAME");

        super.run();
    }
}
```

This will give you access to the `addresses` variable, which is an instance of the `Addresses.sol` contract

### Using with Tests

When writing your [PostProposalCheck](./README.md#post-proposal-check) contract,
you must pass the addresses path to the `TestSuite.t.sol` constructor.

```solidity
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { TestSuite } from "@forge-proposal-simulator/test/TestSuite.t.sol";
import { PROPOSAL_01 } from "path/to/PROPOSAL_01.sol";
import "@forge-std/Test.sol";

contract PostProposalCheck is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    Addresses public addresses;
    TestSuite public suite;

    function setUp() public virtual override {
        // Deploy a new Proposal
        PROPOSAL_01 proposal = new PROPOSAL_01();

        // Add proposal to proposals array
        address[] memory proposalAddresses = new address[](1);
        proposalAddresses[0] = address(proposal);

        // Create TestSuite
        suite = new TestSuite(ADDRESSES_PATH, proposalAddresses);
        
        // Addresses object is available here
        addresses = suite.addresses();

        // Execute proposals
        suite.testProposals();

        // Proposals execution may change addresses, so we need to update the addresses object.
        addresses = suite.addresses();
    }
}
```

Now, your test contract will have access to the `addresses` variable, which is an instance of the `Addresses.sol` contract.
