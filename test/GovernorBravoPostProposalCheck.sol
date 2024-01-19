pragma solidity ^0.8.0;

import "@forge-std/Test.sol";
import {TestSuite} from "@test/TestSuite.t.sol";
import {BRAVO_01} from "@examples/governor-bravo/BRAVO_01.sol";
import {BRAVO_02} from "@examples/governor-bravo/BRAVO_02.sol";
import {BRAVO_03} from "@examples/governor-bravo/BRAVO_03.sol";
import {Addresses} from "@addresses/Addresses.sol";

// @notice this is a helper contract to execute proposals before running integration tests.
// @dev should be inherited by integration test contracts.
contract GovernorBravoPostProposalCheck is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    Addresses public addresses;

    function setUp() public {
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

        // Verify if the governor address is a contract; if is not (e.g. running on a empty blockchain node), deploy a new TimelockController and update the address.
        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        uint256 governorSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            governorSize := extcodesize(governor)
        }
        if (governorSize == 0) {
            // TODO: deploy and configure a new Governor Bravo system.
            // Requires:
            //  - Governance (COMP) token contract
            //  - Governor Bravo Delegate contract (implementation)
            //  - Governor Bravo Delegator contract (proxy)
            //  - Timelock contract
            // After deploying all contracts the proxy implementation must be initialized.
        }
    }
}
