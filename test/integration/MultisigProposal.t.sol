pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import {Vault} from "@examples/Vault.sol";
import {Constants} from "@utils/Constants.sol";
import {MockToken} from "@examples/MockToken.sol";
import {MultisigPostProposalCheck} from "@test/MultisigPostProposalCheck.sol";

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

        assertTrue(timelockVault.tokenWhitelist(address(token)), "Token should be whitelisted");
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
