pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {MultisigPostProposalCheck} from "@test/MultisigPostProposalCheck.sol";

// @dev This test contract inherits MultisigPostProposalCheck, granting it
// the ability to interact with state modifications effected by proposals
// and to work with newly deployed contracts, if applicable.
contract MultisigProposalTest is MultisigPostProposalCheck {
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
