pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/proposalTypes/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Mock} from "@mocks/Mock.sol";
import {Safe} from "@utils/Safe.sol";

// This proposal only deploys 2 contracts 
contract MULTISIG_02 is MultisigProposal {

    function name() public pure override returns(string memory) {
	return "MULTISIG_02";
    }

    function description() public pure override returns(string memory) {
	return "Multisig proposal mock";
     }
    
    function _run(Addresses addresses, address) internal override {
	address multisig = addresses.getAddress("DEV_MULTISIG");

	uint256 multisigSize;
	assembly {
	    // retrieve the size of the code, this needs assembly
            multisigSize := extcodesize(multisig)
	}
	if(multisigSize == 0) {
	    Safe safe = new Safe();
	    vm.etch(multisig, address(safe).code);
	}

	// call etch on multisig address to pretend it is a contract
	_simulateActions(multisig);
    }

    function _deploy(Addresses addresses, address) internal override {
	Mock mock = new Mock();
	Mock mock2 = new Mock();

	addresses.addAddress("MOCK_1", address(mock));
	addresses.addAddress("MOCK_2", address(mock2));
    }

    function _validate(Addresses addresses, address) internal override {
	Mock mock1 = Mock(addresses.getAddress("MOCK_1"));
	assertFalse(mock1.deployed());

	Mock mock2 = Mock(addresses.getAddress("MOCK_2"));
	assertFalse(mock2.deployed());
    }
}
