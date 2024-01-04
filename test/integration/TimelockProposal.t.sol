pragma solidity 0.8.19;

import {TestSuite} from "@test/TestSuite.t.sol";
import {TimelockProposalMock} from "@examples/TimelockProposalMock.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
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
	Addresses addresses = suite.addresses();

	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	uint256 timelockSize;
	assembly {
	    // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
	}
	if(timelockSize == 0) {
	    address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
	    address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

	    address[] memory proposers = new address[](1);
	    proposers[0] = proposer;
	    address[] memory executors = new address[](1);
	    executors[0] = executor;

	    TimelockController timelockController = new TimelockController(10_000, proposers, executors, address(0));
	    addresses.changeAddress("PROTOCOL_TIMELOCK", address(timelockController));
	}

    }

    function test_runPoposals() public virtual {
        preProposalsSnapshot = vm.snapshot();

        suite.setDebug(true);
        suite.testProposals();

        postProposalsSnapshot = vm.snapshot();
    }
}
