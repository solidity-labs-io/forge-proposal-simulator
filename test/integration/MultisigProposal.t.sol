pragma solidity 0.8.19;

import {TestProposals} from "@proposals/TestProposals.sol";
import {MultisigProposalMock} from "@mocks/MultisigProposalMock.sol";
import "@forge-std/Test.sol";

contract MultisigProposalTest is Test {
    string constant public ADDRESSES_PATH = "./addresses/Addresses.json";
    TestProposals public proposals;
    uint256 public preProposalsSnapshot;
    uint256 public postProposalsSnapshot;

    function setUp() public {
	MultisigProposalMock multisigProposal = new MultisigProposalMock();

	address[] memory proposalsAddresses = new address[](1);
	proposalsAddresses[0] = address(multisigProposal);
	proposals = new TestProposals(ADDRESSES_PATH, proposalsAddresses); 
    }

  function test_runPoposals() public virtual {
        preProposalsSnapshot = vm.snapshot();

        proposals.setDebug(true);
        proposals.testProposals();

        postProposalsSnapshot = vm.snapshot();
    }
}
