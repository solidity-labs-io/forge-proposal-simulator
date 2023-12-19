pragma solidity 0.8.19;

import {TestProposals} from "@proposals/TestProposals.sol";

contract MultisigProposalTest is TestProposals {
    string constant addressesPath = "./addresses/Addresses.json";
    string constant proposalArtifactPath = "./mocks/MultisigProposalMock.sol";

    function setUp() public {
	initialize(addressesPath, proposalArtifactPath);
    }
}
