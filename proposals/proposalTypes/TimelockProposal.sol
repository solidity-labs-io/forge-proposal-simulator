pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";

import {Proposal} from "@proposals/proposalTypes/Proposal.sol";
import {ITimelockController} from "@proposals/proposalTypes/ITimelockController.sol";

abstract contract TimelockProposal is Proposal {

  /// @notice log calldata
    function printCalldata() public view override returns(bytes memory data){
        uint256 actionsLength = actions.length;
	address[] targets = new address[](actionsLength);
	uint256[] values = new uint256[](actionsLength);
	uint256[] payloads = new uint256[](actionsLength);
        bytes32 salt = keccak256(abi.encode(actions[0].description));
        bytes32 predecessor = bytes32(0);

        for(uint256 i; i < actionsLength; i++) {
	    targets.push(actions[i].target);
	    payloads.push(actions[i].arguments);
	    values.push(0);
        }

	data = abi.encodeWithSignature("executeBatch(address[],uint256[],bytes[],bytes32,salt)", targets, payloads, values, salt, predecessor);

	if(DEBUG) {
	    console.log("Calldata:");
	    console.logBytes(data);
	}
    }

    /// @notice simulate timelock proposal
    /// @param timelockAddress to execute the proposal against
    /// @param proposerAddress account to propose the proposal to the timelock
    /// @param executorAddress account to execute the proposal on the timelock
    function _simulateTimelockActions(
        address timelockAddress,
        address proposerAddress,
        address executorAddress
    ) internal {
        require(actions.length > 0, "Empty timelock operation");

        ITimelockController timelock = ITimelockController(payable(timelockAddress));
        uint256 delay = timelock.getMinDelay();
        bytes32 salt = keccak256(abi.encode(actions[0].description));

        if (DEBUG) {
            console.log("salt: ");
            emit log_bytes32(salt);
        }

        bytes32 predecessor = bytes32(0);

        uint256 proposalLength = actions.length;
        address[] memory targets = new address[](proposalLength);
        uint256[] memory values = new uint256[](proposalLength);
        bytes[] memory payloads = new bytes[](proposalLength);

        /// target cannot be address 0 as that call will fail
        /// value can be 0
        /// arguments can be 0 as long as eth is sent
        for (uint256 i = 0; i < proposalLength; i++) {
            require(actions[i].target != address(0), "Invalid target for timelock");
            /// if there are no args and no eth, the action is not valid
            require(
                (actions[i].arguments.length == 0 && actions[i].value > 0) || actions[i].arguments.length > 0,
                "Invalid arguments for timelock"
            );

            targets[i] = actions[i].target;
            values[i] = actions[i].value;
            payloads[i] = actions[i].arguments;
        }

        bytes32 proposalId = timelock.hashOperationBatch(targets, values, payloads, predecessor, salt);

        if (!timelock.isOperationPending(proposalId) && !timelock.isOperation(proposalId)) {
            vm.prank(proposerAddress);
            timelock.scheduleBatch(targets, values, payloads, predecessor, salt, delay);

            if (DEBUG) {
                console.log(
                    "schedule batch calldata with ",
                    actions.length,
                    (actions.length > 1 ? " actions" : " action")
                );
                emit log_bytes(
                    abi.encodeWithSignature(
                        "scheduleBatch(address[],uint256[],bytes[],bytes32,bytes32,uint256)",
                        targets,
                        values,
                        payloads,
                        predecessor,
                        salt,
                        delay
                    )
                );
            }
        } else if (DEBUG) {
            console.log("proposal already scheduled for id");
            emit log_bytes32(proposalId);
        }

        vm.warp(block.timestamp + delay);

        if (!timelock.isOperationDone(proposalId)) {
            vm.prank(executorAddress);
            timelock.executeBatch(targets, values, payloads, predecessor, salt);

            if (DEBUG) {
                console.log("execute batch calldata");
                emit log_bytes(
                    abi.encodeWithSignature(
                        "executeBatch(address[],uint256[],bytes[],bytes32,bytes32)",
                        targets,
                        values,
                        payloads,
                        predecessor,
                        salt
                    )
                );
            }
        } else if (DEBUG) {
            console.log("proposal already executed");
        }
    }
}
