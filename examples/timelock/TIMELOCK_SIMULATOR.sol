pragma solidity 0.8.19;

import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {SimpleContract} from "@examples/SimpleContract.sol";
import {TimelockController} from "@utils/TimelockController.sol";

contract GovernorAlpha {
    struct Proposal {
	/// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
	uint eta;

	/// @notice the ordered list of target addresses for calls to be made
	address[] targets;

	/// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
	uint[] values;

	/// @notice The ordered list of function signatures to be called
	string[] signatures;

	/// @notice The ordered list of calldata to be passed to each call
	bytes[] calldatas;
    }

	mapping(uint256 => Proposal) public proposals;


    function getActions(uint proposalId) public view returns (address[] memory targets, uint[] memory values, string[] memory signatures, bytes[] memory calldatas) {Proposal storage p = proposals[proposalId];
	return (p.targets, p.values, p.signatures, p.calldatas);
    }
}

contract TIMELOCK_SIMULATOR is TimelockProposal {
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


    function _build(Addresses addresses, uint256 proposalId) internal override {
	 address governor = addresses.getAddress("GOVERNOR");

	// fetch proposal from Governor contract
	 (address[] memory targets, uint[] memory values, , bytes[] memory calldatas)
	     = GovernorAlpha(governor).getActions(proposalId);

	for (uint256 i; i < targets.length; i++) {
	    // @TODO add signature
	    _pushAction(values[i], targets[i], calldatas[i], "");
	}
    }

    function _validate(Addresses addresses, address) internal override {
	// protocol call invariant tests here, they could use foundry vm.ffi 
    }
}
