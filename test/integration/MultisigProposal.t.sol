pragma solidity 0.8.19;

import {TestProposals} from "@proposals/TestProposals.sol";
import {MultisigProposalMock} from "@mocks/MultisigProposalMock.sol";

contract MultisigProposalTest {
    string constant addressesPath = "./addresses/Addresses.json";
    TestProposals testProposals;

    function setUp() public {
	MultisigProposalMock multisigProposal = new MultisigProposalMock();
	address[] memory proposalsAddresses = new address[](1);
	proposalsAddresses[0] = address(multisigProposal);
	testProposals = new TestProposals(addressesPath, proposalsAddresses); 

	testProposals.testProposals(true, true, true, true, true, true, true, true);
    }

    function test() public {
    }

}
