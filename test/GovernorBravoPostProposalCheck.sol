pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import {GovernorBravoDelegator} from "@comp-governance/GovernorBravoDelegator.sol";
import {GovernorBravoDelegate} from "@comp-governance/GovernorBravoDelegate.sol";
import {Timelock} from "@comp-governance/Timelock.sol";

import {Proposal} from "@proposals/Proposal.sol";
import {MockERC20Votes} from "@mocks/MockERC20Votes.sol";
import {MockGovernorAlpha} from "@mocks/MockGovernorAlpha.sol";
import {Addresses} from "@addresses/Addresses.sol";

/// @notice this is a helper contract to execute a proposal before running integration tests.
/// @dev should be inherited by integration test contracts.
contract GovernorBravoPostProposalCheck is Test {
    Proposal public proposal;
    Addresses public addresses;

    function setUp() public virtual {
        require(
            address(proposal) != address(0),
            "Test must override setUp and set the proposal contract"
        );
        addresses = proposal.addresses();

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        uint256 governorSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            governorSize := extcodesize(governor)
        }
        if (governorSize == 0) {
            address govToken = addresses.getAddress(
                "PROTOCOL_GOVERNANCE_TOKEN"
            );
            uint256 govTokenSize;
            assembly {
                // retrieve the size of the code, this needs assembly
                govTokenSize := extcodesize(govToken)
            }
            if (govTokenSize == 0) {
                // Deploy the governance token
                MockERC20Votes govTokenContract = new MockERC20Votes(
                    "Governance Token",
                    "GOV"
                );
                govToken = address(govTokenContract);

                // Update PROTOCOL_GOVERNANCE_TOKEN address
                addresses.changeAddress(
                    "PROTOCOL_GOVERNANCE_TOKEN",
                    govToken,
                    true
                );
            }

            // Deploy and configure the timelock
            Timelock timelock = new Timelock(address(this), 2 days);

            // Deploy the GovernorBravoDelegate implementation
            GovernorBravoDelegate implementation = new GovernorBravoDelegate();

            // Deploy and configure the GovernorBravoDelegator
            governor = address(
                new GovernorBravoDelegator(
                    address(timelock), // timelock
                    govToken, // governance token
                    address(this), // admin
                    address(implementation), // implementation
                    10_000, // voting period
                    10_000, // voting delay
                    1e21 // proposal threshold
                )
            );

            // Deploy mock GovernorAlpha
            address govAlpha = address(new MockGovernorAlpha());
            // Set GovernorBravo as timelock's pending admin
            vm.prank(address(timelock));
            timelock.setPendingAdmin(governor);
            // Initialize GovernorBravo
            GovernorBravoDelegate(governor)._initiate(govAlpha);

            // Update PROTOCOL_GOVERNOR address
            addresses.changeAddress("PROTOCOL_GOVERNOR", governor, true);
            // Update PROTOCOL_TIMELOCK address
            addresses.changeAddress(
                "PROTOCOL_TIMELOCK",
                address(timelock),
                true
            );
        }

        proposal.run();
    }
}
