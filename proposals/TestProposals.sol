pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";
import {Proposal} from "@proposals/proposalTypes/Proposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {IProposal} from "@proposals/proposalTypes/IProposal.sol";
import {CrossChainProposal} from "@proposals/proposalTypes/CrossChainProposal.sol";
import {CreateCode} from "@utils/CreateCode.sol";
import {Strings} from "@utils/Strings.sol";

/*
How to use:
forge test --fork-url $ETH_RPC_URL --match-contract TestProposals -vvv

Or, from another Solidity file (for post-proposal integration testing):
    TestProposals proposals = new TestProposals();
    proposals.setUp();
    proposals.testProposals();
    Addresses addresses = proposals.addresses();
*/
contract TestProposals is CreateCode {
    using Strings for string;

    Addresses public addresses;
    Proposal[] public proposals;

    function initialize(string memory addressesPath, string memory proposalArtifactPath) public {
        addresses = new Addresses(addressesPath);

        if (keccak256(bytes(proposalArtifactPath)) == '""' || bytes(proposalArtifactPath).length == 0) {
            /// empty string on both mac and unix, no proposals to run
            proposals = new Proposal[](0);
        } else if (proposalArtifactPath.hasChar(",")) {
            string[] memory proposalsPath = proposalArtifactPath.split(",");
            if (proposalsPath.length < 2) {
                revert(
                    "Invalid path(s) provided. If you want to deploy a single proposal, do not use a comma."
                );
            }
            /// guzzle all of the memory, quadratic cost, but we don't care
            for (uint256 i = 0; i < proposalsPath.length; i++) {
                /// deploy each mip and add it to the array
                bytes memory code = getCode(proposalsPath[i]);

                proposals[i] = Proposal(deployCode(code));
            }
        } else {
            bytes memory code = getCode(proposalArtifactPath);
            proposals[0] = Proposal(deployCode(code));
        }
    }

    function printCalldata(
        uint256 index,
        address executor,
        address wormholeCore
    ) public {
        CrossChainProposal(address(proposals[index])).printActions(
            executor,
            wormholeCore
        );
    }

    function printProposalActionSteps() public {
        for (uint256 i = 0; i < proposals.length; i++) {
            proposals[i].printProposalActionSteps();
        }
    }

    function testProposals(
        bool debug,
        bool deploy,
        bool afterDeploy,
        bool afterDeploySetup,
        bool build,
        bool run,
        bool teardown,
        bool validate
    ) public returns (uint256[] memory postProposalVmSnapshots) {
        if (debug) {
            console.log(
                "TestProposals: running",
                proposals.length,
                "proposals."
            );
        }

        postProposalVmSnapshots = new uint256[](proposals.length);
        for (uint256 i = 0; i < proposals.length; i++) {
            string memory name = IProposal(address(proposals[i])).name();

            // Deploy step
            if (deploy) {
                if (debug) {
                    console.log("Proposal", name, "deploy()");
                    addresses.resetRecordingAddresses();
                }
                proposals[i].deploy(addresses, address(proposals[i]));
                if (debug) {
                    (
                        string[] memory recordedNames,
                        address[] memory recordedAddresses
                    ) = addresses.getRecordedAddresses();
                    for (uint256 j = 0; j < recordedNames.length; j++) {
                        console.log("_addAddress('%s',", recordedNames[j]);
                        console.log(block.chainid);
                        console.log(", ");
                        console.log(recordedAddresses[j]);
                        console.log(");");
                    }
                }
            }

            // After-deploy step
            if (afterDeploy) {
                if (debug) console.log("Proposal", name, "afterDeploy()");
                proposals[i].afterDeploy(addresses, address(proposals[i]));
            }

            // After-deploy-setup step
            if (afterDeploySetup) {
                if (debug) console.log("Proposal", name, "afterDeploySetup()");
                proposals[i].afterDeploySetup(addresses);
            }

            // Build step
            if (build) {
                if (debug) console.log("Proposal", name, "build()");
                proposals[i].build(addresses);
            }

            // Run step
            if (run) {
                if (debug) console.log("Proposal", name, "run()");
                proposals[i].run(addresses, address(proposals[i]));
            }

            // Teardown step
            if (teardown) {
                if (debug) console.log("Proposal", name, "teardown()");
                proposals[i].teardown(addresses, address(proposals[i]));
            }

            // Validate step
            if (validate) {
                if (debug) console.log("Proposal", name, "validate()");
                proposals[i].validate(addresses, address(proposals[i]));
            }

            if (debug) console.log("Proposal", name, "done.");

            postProposalVmSnapshots[i] = vm.snapshot();
        }

        return postProposalVmSnapshots;
    }
}
