# Integration Tests

FPS enables the simulation of proposals within integration tests. This
capability is essential for verifying the functionality of your proposals and
ensuring they don't break existing features or ensuring the correctness of a deployment / governance proposal.

## Setting Up PostProposalCheck.sol

The first step is to create a `PostProposalCheck.sol` contract, which serves as
a base for your integration test contracts. This contract is responsable for
deploying proposal contracts, executing them, and updating the addresses object. We'll illustrate this with the Multisig example from our [Multisig Proposal Guide](../guides/multisig-proposal.md).

```solidity
pragma solidity ^0.8.0;

import "@forge-std/Test.sol";
import { MULTISIG_01 } from "path/to/MULTISIG_01.sol";
import { MULTISIG_02 } from "path/to/MULTISIG_02.sol";
import { MULTISIG_03 } from "path/to/MULTISIG_03.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { TestSuite } from "@forge-proposal-simulator/test/TestSuite.t.sol";

// @notice this is a helper contract to execute proposals before running integration tests.
// @dev should be inherited by integration test contracts.
contract MultisigPostProposalCheck is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    Addresses public addresses;

    function setUp() public virtual {
        // Create proposals contracts
        MULTISIG_01 multisigProposal = new MULTISIG_01();
        MULTISIG_02 multisigProposal2 = new MULTISIG_02();
        MULTISIG_03 multisigProposal3 = new MULTISIG_03();

        // Populate addresses array
        address[] memory proposalsAddresses = new address[](3);
        proposalsAddresses[0] = address(multisigProposal);
        proposalsAddresses[1] = address(multisigProposal2);
        proposalsAddresses[2] = address(multisigProposal3);

        // Deploy TestSuite contract
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);

        suite.setDebug(true);
        // Execute proposals
        suite.testProposals();

        // Proposals execution may change addresses, so we need to update the addresses object.
        addresses = suite.addresses();
    }
}
```

Ensure that the `DEV_MULTISIG` address corresponds to a valid Multisig Gnosis Safe contract. If this is not the case, the script will fail, displaying the error: `Multisig address doesn't match Gnosis Safe contract bytecode`.

For those who wish to complete this tutorial on a local blockchain without the
necessity of deploying a Gnosis Safe Account, it is possible to modify the
`setUp` function as follows:

```solidity
bytes public constant SAFE_BYTECODE =
        hex"608060405273ffffffffffffffffffffffffffffffffffffffff600054167fa619486e0000000000000000000000000000000000000000000000000000000060003514156050578060005260206000f35b3660008037600080366000845af43d6000803e60008114156070573d6000fd5b3d6000f3fea2646970667358221220d1429297349653a4918076d650332de1a1068c5f3e07c5c82360c277770b955264736f6c63430007060033";

    function setUp() public virtual {
        // Create proposals contracts
        MULTISIG_01 multisigProposal = new MULTISIG_01();

        // Populate addresses array
        address[] memory proposalsAddresses = new address[](1);
        proposalsAddresses[0] = address(multisigProposal);

        // Deploy TestSuite contract
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);

        // Get addresses object
        addresses = suite.addresses();

        // Set safe bytecode to multisig address
        vm.etch(addresses.getAddress("DEV_MULTISIG"), SAFE_BYTECODE);

        suite.setDebug(true);
        // Execute proposals
        suite.testProposals();

        // Proposals execution may change addresses, so we need to update the addresses object.
        addresses = suite.addresses();
    }
```

## Creating Integration Test Contracts

Next, the creation of the `MultisigProposalIntegrationTest` contract is required, which will inherit from `MultisigPostProposalCheck`. Tests should be added to this contract. Utilize the addresses object within this contract to access the addresses of the contracts that have been deployed by the proposals.

```solidity
pragma solidity ^0.8.0;

import { Vault } from "path/to/Vault.sol";
import { MockToken } from "path/to/MockToken.sol";
import { MultisigPostProposalCheck } from "path/to/MultisigPostProposalCheck.sol";

// @dev This test contract inherits MultisigPostProposalCheck, granting it
// the ability to interact with state modifications effected by proposals
// and to work with newly deployed contracts, if applicable.
contract MultisigProposalIntegrationTest is MultisigPostProposalCheck {
    // Tests if the Vault contract can be paused
    function test_vaultIsPausable() public {
        // Retrieves the Vault instance using its address from the Addresses contract
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        // Retrieves the address of the multisig wallet
        address multisig = addresses.getAddress("DEV_MULTISIG");

        // Sets the next caller of the function to be the multisig address
        vm.prank(multisig);

        // Executes pause function on the Vault
        timelockVault.pause();

        // Asserts that the Vault is successfully paused
        assertTrue(timelockVault.paused(), "Vault should be paused");
    }

    // Tests adding a token to the whitelist in the Vault contract
    function test_addTokenToWhitelist() public {
        // Retrieves the Vault instance using its address from the Addresses contract
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        // Retrieves the address of the multisig wallet
        address multisig = addresses.getAddress("DEV_MULTISIG");
        // Creates a new instance of MockToken
        MockToken token = new MockToken();

        // Sets the next caller of the function to be the multisig address
        vm.prank(multisig);

        // Whitelists the newly created token in the Vault
        timelockVault.whitelistToken(address(token), true);

        // Asserts that the token is successfully whitelisted
        assertTrue(
            timelockVault.tokenWhitelist(address(token)),
            "Token should be whitelisted"
        );
    }

    // Tests deposit functionality in the Vault contract
    function test_depositToVaut() public {
        // Retrieves the Vault instance using its address from the Addresses contract
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        // Retrieves the address of the multisig wallet
        address multisig = addresses.getAddress("DEV_MULTISIG");
        // Retrieves the address of the token to be deposited
        address token = addresses.getAddress("TOKEN_1");

        // Starts a prank session with the multisig address as the caller
        vm.startPrank(multisig);
        // Mints 100 tokens to the current contract's address
        MockToken(token).mint(address(this), 100);
        // Approves the Vault to spend 100 tokens on behalf of this contract
        MockToken(token).approve(address(timelockVault), 100);
        // Deposits 100 tokens into the Vault
        timelockVault.deposit(address(token), 100);

        // Retrieves the deposit amount of the token in the Vault for the multisig address
        (uint256 amount, ) = timelockVault.deposits(address(token), multisig);
        // Asserts that the deposit amount is equal to 100
        assertTrue(amount == 100, "Token should be deposited");
    }
}
```

## Running Integration Tests

Executing the integration tests triggers the `setUp()` function before each test, ensuring the
tests are always executed on a fresh state after the proposals execution.

```bash
forge test --mc MultisigProposalIntegrationTest -vvv
```
