# Integration Tests

FPS enables the simulation of proposals within integration tests. This
capability is essential for verifying the functionality of your proposals and
ensuring they don't break existing features. Additionally, it allows testing of
the entire proposal lifecycle, including governance proposals, and deployment scripts.

## Setting Up PostProposalCheck.sol

The first step is to create a `PostProposalCheck.sol` contract, which serves as
a base for your integration test contracts. This contract is responsible for
deploying proposal contracts, executing them, and updating the addresses object. We'll illustrate this with the Multisig example from our [Multisig Proposal Guide](../guides/multisig-proposal.md).

```solidity
pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import {Constants} from "@utils/Constants.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Proposal} from "@proposals/Proposal.sol";

/// @notice this is a helper contract to execute a proposal before running integration tests.
/// @dev should be inherited by integration test contracts.
contract MultisigPostProposalCheck is Test {
    Proposal public proposal;
    Addresses public addresses;

    function setUp() public virtual {
        require(address(proposal) != address(0), "Test must override setUp and set the proposal contract");
        addresses = proposal.addresses();

        /// @dev Verify if the multisig address is a contract; if it is not
        /// (e.g. running on a empty blockchain node), set the multisig
        /// code to Safe Multisig code
        /// Note: This approach is a workaround for this example where
        /// a deployed multisig contract isn't available. In real-world applications,
        /// you'd typically have a multisig contract in place. Use this code
        /// only as a reference
        bool isContract = addresses.isAddressContract("DEV_MULTISIG");
        address multisig;
        if (!isContract) {
            multisig = addresses.getAddress("DEV_MULTISIG");
            uint256 multisigSize;
            assembly {
                multisigSize := extcodesize(multisig)
            }
            if (multisigSize == 0) {
                vm.etch(multisig, Constants.SAFE_BYTECODE);
            }
        } else {
            multisig = addresses.getAddress("DEV_MULTISIG");
        }

        proposal.run();
    }
}
```

## Creating Integration Test Contracts

Next, the creation of the `MultisigProposalIntegrationTest` contract is required, which will inherit from `MultisigPostProposalCheck`. Tests should be added to this contract. Utilize the addresses object within this contract to access the addresses of the contracts that have been deployed by the proposals.

```solidity
pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {MultisigPostProposalCheck} from "@test/MultisigPostProposalCheck.sol";
import {MULTISIG_01} from "@examples/multisig/MULTISIG_01.sol";

// @dev This test contract inherits MultisigPostProposalCheck, granting it
// the ability to interact with state modifications effected by proposals
// and to work with newly deployed contracts, if applicable.
contract MultisigProposalTest is MultisigPostProposalCheck {
    function setUp() override public {
        proposal = new MULTISIG_01();
        super.setUp();
    }

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
forge test --mc MultisigProposalTest -vvv
```
