pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {TestSuite} from "@test/TestSuite.t.sol";
import {MULTISIG_01} from "@examples/multisig/MULTISIG_01.sol";
import {MULTISIG_02} from "@examples/multisig/MULTISIG_02.sol";
import {MULTISIG_03} from "@examples/multisig/MULTISIG_03.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Constants} from "@utils/Constants.sol";

// @notice this is a helper contract to execute proposals before running integration tests.
// @dev should be inherited by integration test contracts.
contract MultisigPostProposalCheck is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    Addresses public addresses;

    function setUp() public virtual {
        // Create proposals contracts
        MULTISIG_01 multisigProposal = new MULTISIG_01();
        MULTISIG_02 multisigProposal2 = new MULTISIG_02();
        MULTISIG_03 multisigProposal3 = new MULTISIG_03();

        // Populate addresses array
        address[] memory proposalsAddresses = new address[](3);
        proposalsAddresses[0] = address(multisigProposal);
        proposalsAddresses[1] = address(multisigProposal2);
        proposalsAddresses[2] = address(multisigProposal3);

        // Deploy TestSuite contract
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);

        // Set addresses object
        addresses = suite.addresses();

        // @dev Verify if the multisig address is a contract; if it is not
        // (e.g. running on a empty blockchain node), set the multisig
        // code to Safe Multisig code
        // Note: This approach is a workaround for this example where
        // a deployed multisig contract isn't available. In real-world applications,
        // you'd typically have a multisig contract in place. Use this code
        // only as a reference
        address multisig = addresses.getAddress("DEV_MULTISIG");
        uint256 multisigSize;
        assembly {
            multisigSize := extcodesize(multisig)
        }
        if (multisigSize == 0) {
            vm.etch(multisig, Constants.SAFE_BYTECODE);
        }

        suite.setDebug(true);
        // Execute proposals
        suite.testProposals();

        // Proposals execution may change addresses, so we need to update the addresses object.
        addresses = suite.addresses();
    }
}
