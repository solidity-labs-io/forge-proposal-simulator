pragma solidity 0.8.19;

import {TestSuite} from "@test/TestSuite.t.sol";
import {TIMELOCK_01} from "@examples/timelock/TIMELOCK_01.sol";
import {TIMELOCK_02} from "@examples/timelock/TIMELOCK_02.sol";
import {TIMELOCK_03} from "@examples/timelock/TIMELOCK_03.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
import "@forge-std/Test.sol";

contract TimelockProposalTest is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;
    uint256 public preProposalsSnapshot;
    uint256 public postProposalsSnapshot;

    function setUp() public {
        TIMELOCK_01 timelockProposal = new TIMELOCK_01();
        TIMELOCK_02 timelockProposal2 = new TIMELOCK_02();
        TIMELOCK_03 timelockProposal3 = new TIMELOCK_03();

        address[] memory proposalsAddresses = new address[](3);
        proposalsAddresses[0] = address(timelockProposal);
        proposalsAddresses[1] = address(timelockProposal2);
        proposalsAddresses[2] = address(timelockProposal3);

        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);
        Addresses addresses = suite.addresses();

        // Verify if the timelock address is a contract; if is not (e.g. running on a empty blockchain node), deploy a new TimelockController and update the address.
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        uint256 timelockSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
        }
        if (timelockSize == 0) {
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
