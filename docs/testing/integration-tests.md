# Integration Tests

FPS enables the simulation of proposals within integration tests. This
capability is essential for verifying the functionality of your proposals and
ensuring they don't break existing features.

## Setting Up PostProposalCheck.sol

The first step is to create a `PostProposalCheck.sol` contract, which serves as
a base for your integration test contracts. This contract is responsable for
deploying proposal contracts, executing them, and updating the address objects. We'll illustrate this with the Multisig example from our [Multisig Proposal Guide](../guides/multisig-proposal.md).

```solidity
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import { MULTISIG_01 } from "@path/to/MULTISIG_01.sol";
import { MULTISIG_02 } from "@path/to/MULTISIG_02.sol";
import { MULTISIG_03 } from "@path/to/MULTISIG_03.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { Constants } from "@forge-proposal-simulator/utils/Constants.sol";
import { TestSuite } from "@forge-proposal-simulator/test/TestSuite.sol";

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

        // Set addresses object
        addresses = suite.addresses();

        // Verify if the multisig address is a contract; if is not (e.g. running on a empty blockchain node), etch Gnosis Safe bytecode onto it.
        address multisig = addresses.getAddress("DEV_MULTISIG");
        uint256 multisigSize;
        assembly {
            multisigSize := extcodesize(multisig)
        }
        if (multisigSize == 0) {
            vm.etch(multisig, Constants.SAFE_BYTECODE);
        }

        suite.setDebug(true);
        // Execute proposals
        suite.testProposals();

        // Proposals execution may change addresses, so we need to update the addresses object.
        addresses = suite.addresses();
    }
}
```

## Creating Integration Test Contracts

Next, we create the `MultisigProposalTest` contract, inheriting
`MultisigPostProposalCheck`. This contract execute specific test cases to
validate your proposal's functionality and ensure it doesn't break existing
features.

```solidity
import { Vault } from "path/to/Vault.sol";
import { MockToken } from "path/to/MockToken.sol";
import { MultisigPostProposalCheck } from "path/to/MultisigPostProposalCheck.sol";

contract MultisigProposalTest is MultisigPostProposalCheck {
    function test_vaultIsPausable() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address multisig = addresses.getAddress("DEV_MULTISIG");

        vm.prank(multisig);

        timelockVault.pause();

        assertTrue(timelockVault.paused(), "Vault should be paused");
    }

    function test_addTokenToWhitelist() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address multisig = addresses.getAddress("DEV_MULTISIG");
        MockToken token = new MockToken();

        vm.prank(multisig);

        timelockVault.whitelistToken(address(token), true);

        assertTrue(
            timelockVault.tokenWhitelist(address(token)),
            "Token should be whitelisted"
        );
    }

    function test_depositToVaut() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address multisig = addresses.getAddress("DEV_MULTISIG");
        address token = addresses.getAddress("TOKEN_1");

        vm.startPrank(multisig);
        MockToken(token).mint(address(this), 100);
        MockToken(token).approve(address(timelockVault), 100);
        timelockVault.deposit(address(token), 100);

        (uint256 amount, ) = timelockVault.deposits(address(token), multisig);
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
