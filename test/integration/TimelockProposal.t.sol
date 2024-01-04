pragma solidity 0.8.19;

import {TestSuite} from "@test/TestSuite.t.sol";
import {TimelockProposalMock} from "@examples/TimelockProposalMock.sol";
import {TimelockController} from "@utils/TimelockController.sol";
import {Constants} from "@utils/Constants.sol";
import "@forge-std/Test.sol";

contract TimelockProposalTest is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    uint256 public preProposalsSnapshot;
    uint256 public postProposalsSnapshot;

    function setUp() public {
        TimelockProposalMock timelockProposal = new TimelockProposalMock();

        address[] memory proposalsAddresses = new address[](1);
        proposalsAddresses[0] = address(timelockProposal);

        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);
	address timelock = suite.addresses().getAddress("PROTOCOL_TIMELOCK");

	uint256 timelockSize;
	assembly {
	    // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
	}
	if(timelockSize == 0) {
	    vm.etch(timelock, Constants.TIMELOCK_BYTECODE);
	    // set a delay if is running on a local instance 
	    //TimelockController(payable(timelock)).updateDelay(10_000);
	}

    }

    function test_runPoposals() public virtual {
        preProposalsSnapshot = vm.snapshot();

        suite.setDebug(true);
        suite.testProposals();

        postProposalsSnapshot = vm.snapshot();
    }
}
