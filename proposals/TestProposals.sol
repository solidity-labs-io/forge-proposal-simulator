pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";
import {Proposal} from "@proposals/proposalTypes/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Strings} from "@utils/Strings.sol";
import {Test} from "@forge-std/Test.sol";

/*
How to use:
forge test --fork-url $ETH_RPC_URL --match-contract TestProposals -vvv

Or, from another Solidity file (for post-proposal integration testing):
    TestProposals proposals = new TestProposals();
    proposals.setUp();
    proposals.testProposals();
    Addresses addresses = proposals.addresses();
*/
contract TestProposals is Test {
    using Strings for string;

    Addresses public addresses;
    Proposal[] public proposals;
    bool public debug;

    constructor(string memory addressesPath, address[] memory _proposals) {
        addresses = new Addresses(addressesPath);

	proposals = new Proposal[](_proposals.length);
	for(uint256 i; i < _proposals.length; i++) {
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
            console.log("TestProposals: running", proposals.length, "proposals.");

		/// output deployed contract addresses and names
	    (string[] memory recordedNames, ,address[] memory recordedAddresses) = addresses.getRecordedAddresses();
		for (uint256 j = 0; j < recordedNames.length; j++) {
		    console.log("Deployed", recordedAddresses[j], recordedNames[j]);
		}

        }

        /// evm snapshot array
        postProposalVmSnapshots = new uint256[](proposals.length);

        for (uint256 i = 0; i < proposals.length; i++) {
            string memory name = proposals[i].name();
	    if(debug) {
		console.log("Proposal name:", name);
	    }

            // Run the deploy for testing only workflow
            proposals[i].run(addresses, address(this), true, true, true, true, true, true);

            /// take new snapshot
            postProposalVmSnapshots[i] = vm.snapshot();
        }
	return postProposalVmSnapshots;
    }
}
