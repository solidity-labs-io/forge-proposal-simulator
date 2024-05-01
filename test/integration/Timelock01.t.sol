pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {TimelockPostProposalCheck} from "@test/TimelockPostProposalCheck.sol";
import {TIMELOCK_01} from "@examples/timelock/TIMELOCK_01.sol";

// @dev This test contract extends TimelockPostProposalCheck, granting it
// the ability to interact with state modifications effected by proposals
// and to work with newly deployed contracts, if applicable.
contract Timelock01ProposalTest is TimelockPostProposalCheck {
    function setUp() public override {
        proposal = new TIMELOCK_01();
        vm.makePersistent(address(proposal));

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

        vm.startPrank(timelock);
        MockToken(token).mint(address(this), 100);
        MockToken(token).approve(address(timelockVault), 100);
        timelockVault.deposit(address(token), 100);

        (uint256 amount, ) = timelockVault.deposits(address(token), timelock);
        assertTrue(amount == 100, "Token should be deposited");
    }

    function test_matchCalldata() public view {
        assertTrue(
            proposal.checkOnChainCalldata(
                addresses.getAddress("PROTOCOL_TIMELOCK")
            ),
            "Calldata does not match on-chain proposal"
        );
    }
}
