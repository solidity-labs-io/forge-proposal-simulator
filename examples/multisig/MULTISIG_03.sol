pragma solidity 0.8.19;

import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";
import {Safe} from "@utils/Safe.sol";

// This proposal set variable deployed = true on two contracts 
contract MULTISIG_03 is MultisigProposal {

    function name() public pure override returns(string memory) {
	return "MULTISIG_03";
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

    function _build(Addresses addresses) internal override {
	address mock1 = addresses.getAddress("MOCK_3");
	_pushAction(mock1, abi.encodeWithSignature("setDeployed(bool)", true), "Set deployed to true");

	address mock2 = addresses.getAddress("MOCK_4");
	_pushAction(mock2, abi.encodeWithSignature("setDeployed(bool)", true), "Set deployed to true");
    }

    function _validate(Addresses addresses, address) internal override {
	SimpleContract mock1 = SimpleContract(addresses.getAddress("MOCK_3"));
	assertTrue(mock1.deployed());

	SimpleContract mock2 = SimpleContract(addresses.getAddress("MOCK_4"));
	assertTrue(mock2.deployed());
    }
}
