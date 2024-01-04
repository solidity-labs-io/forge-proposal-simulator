pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";
import {Proposal} from "@proposals/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Test} from "@forge-std/Test.sol";

/*
How to use:
forge test --fork-url $ETH_RPC_URL --match-contract -vvv

Or, from another Solidity file (for post-proposal integration testing):
    TestSuite suite = new TestSuite();
    suite.setUp();
    suite.testProposals();
    Addresses addresses = proposals.addresses();
*/
contract TestSuite is Test {
    using Strings for string;

    Addresses public addresses;
    Proposal[] public proposals;
    bool public debug;

    constructor(string memory addressesPath, address[] memory _proposals) {
        addresses = new Addresses(addressesPath);

        proposals = new Proposal[](_proposals.length);
        for (uint256 i; i < _proposals.length; i++) {
            proposals[i] = Proposal(_proposals[i]);
        }
    }

    function setDebug(bool value) public {
        debug = value;
        for (uint256 i = 0; i < proposals.length; i++) {
            proposals[i].setDebug(value);
        }
    }

    function testProposals() public returns (uint256[] memory postProposalVmSnapshots) {
        if (debug) {
            console.log("TestSuite: running", proposals.length, "proposals.");

	    console.log("Addresses before running proposals:");
            /// output deployed contract addresses and names
            (string[] memory recordedNames, , address[] memory recordedAddresses) = addresses.getRecordedAddresses();
            for (uint256 j = 0; j < recordedNames.length; j++) {
                console.log(recordedNames[j], recordedAddresses[j]);
            }
        }

        /// evm snapshot array
        postProposalVmSnapshots = new uint256[](proposals.length);

        for (uint256 i = 0; i < proposals.length; i++) {
            string memory name = proposals[i].name();
            if (debug) {
                console.log("Proposal name:", name);
            }

            proposals[i].run(addresses, address(this));

            /// take new snapshot
            postProposalVmSnapshots[i] = vm.snapshot();
        }

        if (debug) {
	    console.log("Addresses after running proposals:");
            /// output deployed contract addresses and names
            (string[] memory recordedNames, , address[] memory recordedAddresses) = addresses.getRecordedAddresses();
            for (uint256 j = 0; j < recordedNames.length; j++) {
                console.log(recordedNames[j], recordedAddresses[j]);
	     }
        }

        return postProposalVmSnapshots;
    }
}
