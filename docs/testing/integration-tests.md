# Integration Tests

FPS enables the simulation of proposals within integration tests. This capability is essential for verifying the functionality of your proposals and ensuring they don't break existing features. Additionally, it allows testing of the entire proposal lifecycle, including governance proposals and deployment scripts. This guide illustrates writing integration tests with the Multisig example from our [Multisig Proposal Guide](../guides/multisig-proposal.md). These integration tests have already been implemented in the fps-example repo [here](https://github.com/solidity-labs-io/fps-example-repo/tree/main/test/multisig).

## Setting Up PostProposalCheck.sol

The first step is to create a `PostProposalCheck.sol` contract, which serves as a base for your integration test contracts. This contract is responsible for deploying proposal contracts, executing them, and updating the addresses object. This allows integration tests to run against the newly updated state after all changes from the governance proposal go into effect.

```solidity
pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import { MultisigProposal } from "@forge-proposal-simulator/src/proposals/MultisigProposal.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";

// @notice this is a helper contract to execute proposals before running integration tests.
// @dev should be inherited by integration test contracts.
contract MultisigPostProposalCheck is Test {
    Addresses public addresses;

    function setUp() public virtual {
        string[] memory inputs = new string[](2);
        inputs[0] = "./get-latest-proposal.sh";
        inputs[1] = "MultisigProposal";

        string memory output = string(vm.ffi(inputs));

        MultisigProposal multisigProposal = MultisigProposal(
            deployCode(output)
        );
        vm.makePersistent(address(multisigProposal));

        // Execute proposals
        multisigProposal.run();

        addresses = multisigProposal.addresses();
    }
}
```

## Creating a script that returns the latest proposal based on the type of proposal.

```bash
#!/bin/bash
BASE_DIR="out"

PROPOSAL_TYPE="$1"

# Find proposal directories and get the latest one
LATEST_PROPOSAL_DIR=$(ls -1v ${BASE_DIR}/ | grep "^$PROPOSAL_TYPE" | tail -n 1)

LATEST_FILE="${LATEST_PROPOSAL_DIR%.sol}"

# Print the path to the latest proposal artifact json file
echo "${BASE_DIR}/${LATEST_PROPOSAL_DIR}/${LATEST_FILE}.json"
```

## Creating Integration Test Contracts

Next, the creation of the `MultisigProposalIntegrationTest` contract is required, which will inherit from `MultisigPostProposalCheck`. Tests should be added to this contract. Utilize the addresses object within this contract to access the addresses of the contracts that have been deployed by the proposals.

```solidity
pragma solidity ^0.8.0;

import { Vault } from "src/mocks/Vault.sol";
import { Token } from "src/mocks/Token.sol";
import { MultisigPostProposalCheck } from "./MultisigPostProposalCheck.sol";

// @dev This test contract inherits MultisigPostProposalCheck, granting it
// the ability to interact with state modifications effected by proposals
// and to work with newly deployed contracts, if applicable.
contract MultisigProposalIntegrationTest is MultisigPostProposalCheck {
    // Tests adding a token to the whitelist in the Vault contract
    function test_addTokenToWhitelist() public {
        // Retrieves the Vault instance using its address from the Addresses contract
        Vault multisigVault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        // Retrieves the address of the multisig wallet
        address multisig = addresses.getAddress("DEV_MULTISIG");
        // Creates a new instance of Token
        Token token = new Token();

        // Sets the next caller of the function to be the multisig address
        vm.prank(multisig);

        // Whitelists the newly created token in the Vault
        multisigVault.whitelistToken(address(token), true);

        // Asserts that the token is successfully whitelisted
        assertTrue(
            multisigVault.tokenWhitelist(address(token)),
            "Token should be whitelisted"
        );
    }

    // Tests deposit functionality in the Vault contract
    function test_depositToVault() public {
        // Retrieves the Vault instance using its address from the Addresses contract
        Vault multisigVault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        // Retrieves the address of the multisig wallet
        address multisig = addresses.getAddress("DEV_MULTISIG");
        // Retrieves the address of the token to be deposited
        address token = addresses.getAddress("MULTISIG_TOKEN");

        (uint256 prevDeposits, ) = multisigVault.deposits(
            address(token),
            multisig
        );

        uint256 depositAmount = 100;

        // Starts a prank session with the multisig address as the caller
        vm.startPrank(multisig);
        // Mints 100 tokens to the multisig contract's address
        Token(token).mint(multisig, depositAmount);
        // Approves the Vault to spend depositAmount tokens
        Token(token).approve(address(multisigVault), depositAmount);
        // Deposits depositAmount tokens into the Vault
        multisigVault.deposit(address(token), depositAmount);

        // Retrieves the deposit amount of the token in the Vault for the multisig address
        (uint256 amount, ) = multisigVault.deposits(address(token), multisig);
        // Asserts that the deposit amount is equal to previous deposit + depositAmount
        assertTrue(
            amount == prevDeposits + depositAmount,
            "Token should be deposited"
        );
    }
}
```

## Running Integration Tests

Executing the integration tests triggers the `setUp()` function before each test, ensuring the
tests are always executed on a fresh state after the proposals execution.

```bash
forge test --mc MultisigProposalIntegrationTest -vvv --ffi
```
