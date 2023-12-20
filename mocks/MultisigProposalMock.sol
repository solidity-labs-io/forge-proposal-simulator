pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/proposalTypes/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract Mock {
    bool public deployed;

    function setDeployed(bool _deployed) external {
	deployed = _deployed;
    }
}

contract MultisigProposalMock is MultisigProposal {

    function name() public pure override returns(string memory) {
	return "MULTISIG_PROPOSAL_MOCK_01";
    }
    
    function _run(Addresses addresses, address) internal override {
	address multisig = addresses.getAddress("DEV_MULTISIG");

	// call etch on multisig address to pretend it is a contract
	vm.etch(multisig, "0x01");
	_simulateActions(multisig);
    }

    function _deploy(Addresses addresses, address) internal override {
	Mock mock = new Mock();
	Mock mock2 = new Mock();

	addresses.addAddress("MOCK_1", address(mock));
	addresses.addAddress("MOCK_2", address(mock2));
    }

    function _build(Addresses addresses) internal override {
	address mock1 = addresses.getAddress("MOCK_1");
	_pushAction(mock1, abi.encodeWithSignature("setDeployed(bool)", true), "Set deployed to true");

	address mock2 = addresses.getAddress("MOCK_2");
	_pushAction(mock2, abi.encodeWithSignature("setDeployed(bool)", true), "Set deployed to true");
    }

    function _validate(Addresses addresses, address) internal override {
	Mock mock1 = Mock(addresses.getAddress("MOCK_1"));
	assertTrue(mock1.deployed());

	Mock mock2 = Mock(addresses.getAddress("MOCK_2"));
	assertTrue(mock2.deployed());
    }
}
