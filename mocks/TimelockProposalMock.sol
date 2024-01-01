pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Mock} from "@mocks/Mock.sol";
import {TimelockController} from "@utils/TimelockController.sol";

contract TimelockProposalMock is TimelockProposal {

    function name() public pure override returns(string memory) {
	return "TIMELOCK_PROPOSAL_MOCK";
    }

    function description() public pure override returns(string memory) {
	return "Timelock proposal mock";
     }
    
    function _run(Addresses addresses, address) internal override {
	address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
	address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
	address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

	uint256 timelockSize;
	assembly {
	    // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
	}
	if(timelockSize == 0) {
	    TimelockController timelockController = new TimelockController();
	    vm.etch(timelock, address(timelockController).code);
	    // set a delay if is running on a local instance 
	    TimelockController(payable(timelock)).updateDelay(10_000);
	}

	_simulateActions(timelock, proposer, executor);
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
