pragma solidity ^0.8.0;

import {Addresses} from "@addresses/Addresses.sol";

interface IProposal {
    /// @notice proposal name, e.g. "BIP15"
    /// @dev override this to set the proposal name
    function name() external view returns (string memory);

    /// @notice proposal description
    /// @dev override this to set the proposal description
    function description() external view returns (string memory);

    /// @notice actually run the proposal
    /// @dev review the implementation to determine which internal functions
    /// might need overriding for you proposal
    function run() external;

    /// @notice Print proposal actions
    function getProposalActions()
        external
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory arguments
        );

    /// @notice Return proposal calldata
    function getCalldata() external returns (bytes memory data);

    /// @notice Check if there are any on-chain proposal that matches the
    /// proposal calldata
    function checkOnChainCalldata(address addr) external returns (bool);

    /// @notice Return Addresses object
    function addresses() external view returns (Addresses);
}
