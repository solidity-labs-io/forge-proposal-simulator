pragma solidity ^0.8.0;

import "@forge-std/Test.sol";
import {TestSuite} from "@test/TestSuite.t.sol";
import {BRAVO_01} from "@examples/governor-bravo/BRAVO_01.sol";
import {BRAVO_02} from "@examples/governor-bravo/BRAVO_02.sol";
import {BRAVO_03} from "@examples/governor-bravo/BRAVO_03.sol";
import {MockERC20Votes} from "@test/mocks/MockERC20Votes.sol";
import {MockGovernorAlpha} from "@test/mocks/MockGovernorAlpha.sol";
import {GovernorBravoDelegator} from "@comp-governance/GovernorBravoDelegator.sol";
import {GovernorBravoDelegate} from "@comp-governance/GovernorBravoDelegate.sol";
import {Timelock} from "@comp-governance/Timelock.sol";
import {Addresses} from "@addresses/Addresses.sol";

// @notice this is a helper contract to execute proposals before running integration tests.
// @dev should be inherited by integration test contracts.
contract GovernorBravoPostProposalCheck is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    Addresses public addresses;
    bool public checkCalldata;

    function setUp() public virtual {
        BRAVO_01 governorProposal1 = new BRAVO_01();
        BRAVO_02 governorProposal2 = new BRAVO_02();
        BRAVO_03 governorProposal3 = new BRAVO_03();

        // Populate addresses array
        address[] memory proposalsAddresses = new address[](3);
        proposalsAddresses[0] = address(governorProposal1);
        proposalsAddresses[1] = address(governorProposal2);
        proposalsAddresses[2] = address(governorProposal3);

        // Deploy TestSuite contract
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);

        // Set addresses object
        addresses = suite.addresses();

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        uint256 governorSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            governorSize := extcodesize(governor)
        }
        if (governorSize != 0) checkCalldata = true;
        else {
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
                addresses.changeAddress("PROTOCOL_GOVERNANCE_TOKEN", govToken);
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
            addresses.changeAddress("PROTOCOL_GOVERNOR", governor);
            // Update PROTOCOL_TIMELOCK address
            addresses.changeAddress("PROTOCOL_TIMELOCK", address(timelock));
        }

        suite.setDebug(true);
        // Execute proposals
        suite.testProposals();

        // Proposals execution may change addresses, so we need to update the addresses object.
        addresses = suite.addresses();
    }
}
