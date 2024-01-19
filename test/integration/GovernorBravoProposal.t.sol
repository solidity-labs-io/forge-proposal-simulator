pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {GovernorBravoPostProposalCheck} from "@test/GovernorBravoPostProposalCheck.sol";
import "@forge-std/Test.sol";

// @dev This test contract extends GovernorBravoProposalTest, granting it
// the ability to interact with state modifications effected by proposals
// and to work with newly deployed contracts, if applicable.
contract GovernorBravoProposalTest is GovernorBravoPostProposalCheck {
    function test_vaultIsPausable() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");

        vm.prank(governor);

        timelockVault.pause();

        assertTrue(timelockVault.paused(), "Vault should be paused");
    }

    function test_addTokenToWhitelist() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        MockToken token = new MockToken();

        vm.prank(governor);

        timelockVault.whitelistToken(address(token), true);

        assertTrue(
            timelockVault.tokenWhitelist(address(token)),
            "Token should be whitelisted"
        );
    }

    function test_depositToVaut() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        address token = addresses.getAddress("TOKEN_1");

        vm.startPrank(governor);
        MockToken(token).mint(address(this), 100);
        MockToken(token).approve(address(timelockVault), 100);
        timelockVault.deposit(address(token), 100);

        (uint256 amount, ) = timelockVault.deposits(address(token), governor);
        assertTrue(amount == 100, "Token should be deposited");
    }
}
