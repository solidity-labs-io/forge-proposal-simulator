pragma solidity ^0.8.0;

import "@forge-std/Test.sol";
import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {MockERC20Votes} from "@test/mocks/MockERC20Votes.sol";
import "@forge-std/Test.sol";
import {Proposal} from "@proposals/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Timelock} from "@comp-governance/Timelock.sol";
import {GovernorBravoDelegate} from "@comp-governance/GovernorBravoDelegate.sol";
import {GovernorBravoDelegator} from "@comp-governance/GovernorBravoDelegator.sol";
import {MockGovernorAlpha} from "@test/mocks/MockGovernorAlpha.sol";
import {BRAVO_01} from "@examples/governor-bravo/BRAVO_01.sol";
import {GovernorBravoPostProposalCheck} from "@test/GovernorBravoPostProposalCheck.sol";

contract Bravo01IntegrationTest is GovernorBravoPostProposalCheck {
    function setUp() override public {
        proposal = new BRAVO_01();
        super.setUp();
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

        vm.prank(timelock);
        MockToken(token).mint(address(this), 100);

        MockToken(token).approve(address(timelockVault), 100);
        timelockVault.deposit(address(token), 100);

        (uint256 amount, ) = timelockVault.deposits(
                                                    address(token),
                                                    address(this)
        );
        assertTrue(amount == 100, "Token should be deposited");
    }
}
