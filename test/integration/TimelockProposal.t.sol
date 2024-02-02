pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {TimelockPostProposalCheck} from "@test/TimelockPostProposalCheck.sol";
import "@forge-std/Test.sol";

// @dev This test contract extends TimelockPostProposalCheck, granting it
// the ability to interact with state modifications effected by proposals
// and to work with newly deployed contracts, if applicable.
contract TimelockProposalTest is TimelockPostProposalCheck {
    // Check if simulated calldatas match the ones from the forked environment.
    function test_calldataMatch() public {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        bool[] memory matches = suite.checkProposalCalldatas(timelock);
        if (checkCalldata) {
            for (uint256 i; i < matches.length; i++) {
                assertTrue(matches[i]);
            }
        } else {
            console2.log("Skipping calldata check");
        }
    }

    function test_vaultIsPausable() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");

        vm.prank(timelock);

        timelockVault.pause();

        assertTrue(timelockVault.paused(), "Vault should be paused");
    }

    function test_addTokenToWhitelist() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        MockToken token = new MockToken();

        vm.prank(timelock);

        timelockVault.whitelistToken(address(token), true);

        assertTrue(
            timelockVault.tokenWhitelist(address(token)),
            "Token should be whitelisted"
        );
    }

    function test_depositToVaut() public {
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        address token = addresses.getAddress("TOKEN_1");

        vm.startPrank(timelock);
        MockToken(token).mint(address(this), 100);
        MockToken(token).approve(address(timelockVault), 100);
        timelockVault.deposit(address(token), 100);

        (uint256 amount, ) = timelockVault.deposits(address(token), timelock);
        assertTrue(amount == 100, "Token should be deposited");
    }
}
