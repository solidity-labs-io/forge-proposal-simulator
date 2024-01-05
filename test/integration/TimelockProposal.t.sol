pragma solidity 0.8.19;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {TimelockPostProposalCheck} from "@test/TimelockPostProposalCheck.sol";
import "@forge-std/Test.sol";

contract TimelockProposalTest is TimelockPostProposalCheck {
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

        assertTrue(timelockVault.tokenWhitelist(address(token)), "Token should be whitelisted");
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
