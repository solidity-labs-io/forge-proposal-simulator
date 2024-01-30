pragma solidity ^0.8.0;

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

    function testProposals()
        public
        returns (uint256[] memory postProposalVmSnapshots)
    {
        if (debug) {
            console.log("TestSuite: running", proposals.length, "proposals.");
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
            console.log("Addresses added after running proposals:");
            /// output deployed contract addresses and names
            (
                string[] memory recordedNames,
                ,
                address[] memory recordedAddresses
            ) = addresses.getRecordedAddresses();
            for (uint256 j = 0; j < recordedNames.length; j++) {
                console.log(recordedNames[j], recordedAddresses[j]);
            }
        }

        return postProposalVmSnapshots;
    }

    function checkProposalCalldatas(address governor) public returns (bool[] memory calldataMatches) {
        if (debug) {
            console.log("TestSuite: comparing", proposals.length, "proposals.");
        }

        /// evm snapshot array
        calldataMatches = new bool[](proposals.length);

        for (uint256 i = 0; i < proposals.length; i++) {
            string memory name = proposals[i].name();
            if (debug) {
                console.log("Proposal id:", proposals[i].id());
                console.log("Proposal name:", name);
            }

            bytes memory dataSim = proposals[i].getCalldata();
            bytes memory dataFork = proposals[i].getForkCalldata(governor);
            bool check = _bytesMatch(dataSim, dataFork);

            if (debug) {
                if (check) {
                    console.log(
                        "  > Simulated calldata matches proposal id %s in the forked environment",
                        proposals[i].id()
                    );
                } else {
                    console.log(
                        "  x Simulated calldata does not match proposal id %s in the forked environment",
                        proposals[i].id()
                    );
                }
            }

            calldataMatches[i] = check;
        }

        return calldataMatches;
    }

    function _bytesMatch(bytes memory a_, bytes memory b_) internal pure returns (bool) {
        if(a_.length != b_.length) {
            return false;
        }
        for (uint i = 0; i < a_.length; i++) {
            if(a_[i] != b_[i]) {
                return false;
            }
        }
        return true;
    }

}
