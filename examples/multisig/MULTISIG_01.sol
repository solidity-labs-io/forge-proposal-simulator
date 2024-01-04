pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";

// MULTISIG_01: A proposal contract for deploying and manipulating two mock contracts.
contract MULTISIG_01 is MultisigProposal {

    // Returns the name of the proposal.
    function name() public pure override returns(string memory) {
        return "MULTISIG_01";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns(string memory) {
        return "Multisig proposal mock";
    }

    // Deploys two mock contracts and registers their addresses.
    function _deploy(Addresses addresses, address) internal override {
        SimpleContract mock1 = new SimpleContract();
        SimpleContract mock2 = new SimpleContract();

	address devMultisig = addresses.getAddress("DEV_MULTISIG");
	mock1.transferOwnership(devMultisig);
	mock2.transferOwnership(devMultisig);

        addresses.addAddress("MOCK_1", address(mock1));
        addresses.addAddress("MOCK_2", address(mock2));
    }

    // Sets up actions for the proposal, marking the mock contracts as active.
    function _build(Addresses addresses) internal override {
        address mock1 = addresses.getAddress("MOCK_1");
        _pushAction(mock1, abi.encodeWithSignature("setActive(bool)", true), "Set active to true");

        address mock2 = addresses.getAddress("MOCK_2");
        _pushAction(mock2, abi.encodeWithSignature("setActive(bool)", true), "Set active to true");
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
        address multisig = addresses.getAddress("DEV_MULTISIG");

        _simulateActions(multisig);
    }

    // Validates the post-execution state of the mock contracts.
    function _validate(Addresses addresses, address) internal override {
        SimpleContract mock1 = SimpleContract(addresses.getAddress("MOCK_1"));
        assertTrue(mock1.active());

        SimpleContract mock2 = SimpleContract(addresses.getAddress("MOCK_2"));
        assertTrue(mock2.active());
    }
}
