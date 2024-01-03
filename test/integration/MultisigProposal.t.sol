pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import {TestSuite} from "@test/TestSuite.t.sol";
import {MULTISIG_01} from "@examples/multisig/MULTISIG_01.sol";
import {MULTISIG_02} from "@examples/multisig/MULTISIG_02.sol";
import {MULTISIG_03} from "@examples/multisig/MULTISIG_03.sol";
import {Constants} from "@utils/Constants.sol";

contract MultisigProposalTest is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    uint256 public preProposalsSnapshot;
    uint256 public postProposalsSnapshot;

    function setUp() public {
        MULTISIG_01 multisigProposal = new MULTISIG_01();
        MULTISIG_02 multisigProposal2 = new MULTISIG_02();
        MULTISIG_03 multisigProposal3 = new MULTISIG_03();

        address[] memory proposalsAddresses = new address[](3);
        proposalsAddresses[0] = address(multisigProposal);
        proposalsAddresses[1] = address(multisigProposal2);
        proposalsAddresses[2] = address(multisigProposal3);
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);

        address multisig = suite.addresses().getAddress("DEV_MULTISIG");
        uint256 multisigSize;
        assembly {
            multisigSize := extcodesize(multisig)
        }
        if (multisigSize == 0) {
            vm.etch(multisig, Constants.SAFE_BYTECODE);
        }
    }

    function test_runPoposals() public virtual {
        preProposalsSnapshot = vm.snapshot();

        suite.setDebug(true);
        suite.testProposals();

        postProposalsSnapshot = vm.snapshot();
    }
}
