pragma solidity 0.8.19;

import {TestSuite} from "@test/TestSuite.t.sol";
import {MULTISIG_01} from "@mocks/multisig/MULTISIG_01.sol";
import {MULTISIG_02} from "@mocks/multisig/MULTISIG_02.sol";
import "@forge-std/Test.sol";

contract MultisigProposalTest is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    uint256 public preProposalsSnapshot;
    uint256 public postProposalsSnapshot;

    function setUp() public {
        MULTISIG_01 multisigProposal = new MULTISIG_01();
        MULTISIG_02 multisigProposal2 = new MULTISIG_02();

        address[] memory proposalsAddresses = new address[](2);
        proposalsAddresses[0] = address(multisigProposal);
        proposalsAddresses[1] = address(multisigProposal2);
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);
    }

    function test_runPoposals() public virtual {
        preProposalsSnapshot = vm.snapshot();

        suite.setDebug(true);
        suite.testProposals();

        postProposalsSnapshot = vm.snapshot();
    }
}
