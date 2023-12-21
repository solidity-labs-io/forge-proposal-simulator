pragma solidity 0.8.19;

import {Addresses} from "@addresses/Addresses.sol";

interface IProposal {
    // @notice proposal name, e.g. "BIP15"
    // @dev override this to set the proposal name
    function name() external view returns (string memory);

    // @notice actually run the proposal
    // @dev review the implementation to determine which internal functions
    // might need overriding for you proposal
    function run(Addresses addresses, address deployer,
 		 bool deploy,
		 bool afterDeploy,
		 bool build,
		 bool run,
		 bool teardown,
		 bool validate) external;

    // @notice actually run the proposal
    // @dev review the implementation to determine which internal functions
    // might need overriding for you proposal
    function run(Addresses addresses, address deployer) external;

    // @notice Print out proposal steps one by one
    // print proposal description
    function printProposalActionSteps() external;

    // @notice Print proposal calldata
    function printCalldata() external returns(bytes memory data);
}
