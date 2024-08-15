pragma solidity ^0.8.0;

import {Addresses} from "@addresses/Addresses.sol";

interface IProposal {
    /// @notice proposal name, e.g. "BIP15".
    /// @dev override this to set the proposal name.
    function name() external view returns (string memory);

    /// @notice proposal description.
    /// @dev override this to set the proposal description.
    function description() external view returns (string memory);

    /// @notice function to be used by forge script.
    /// @dev use flags to determine which actions to take
    ///      this function shoudn't be overriden.
    function run() external;

    /// @notice return proposal actions.
    /// @dev this function shoudn't be overriden.
    function getProposalActions()
        external
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory arguments
        );

    /// @notice return proposal calldata
    function getCalldata() external returns (bytes memory data);

    /// @notice check and return proposal id if there are any on-chain proposal that matches the
    /// proposal calldata
    function getProposalId() external returns (uint256);

    /// @notice return Addresses object
    function addresses() external view returns (Addresses);

    /// @notice deploy any contracts needed for the proposal.
    /// @dev contracts calls here are broadcast if the broadcast flag is set.
    function deploy() external;

    /// @notice helper function to mock on-chain data before build
    ///         e.g. pranking, etching, etc.
    function preBuildMock() external;

    /// @notice build the proposal actions
    /// @dev contract calls must be perfomed in plain solidity.
    ///      overriden requires using buildModifier modifier to leverage
    ///      foundry snapshot and state diff recording to populate the actions array.
    function build() external;

    /// @notice actually simulates the proposal.
    ///         e.g. schedule and execute on Timelock Controller,
    ///         proposes, votes and execute on Governor Bravo, etc.
    function simulate() external;

    /// @notice execute post-proposal checks.
    ///          e.g. read state variables of the deployed contracts to make
    ///          sure they are deployed and initialized correctly, or read
    ///          states that are expected to have changed during the simulate step.
    function validate() external;

    /// @notice print proposal description, actions and calldata
    function print() external;

    /// @notice set the Addresses contract
    function setAddresses(Addresses _addresses) external;

    /// @notice set the primary fork id
    function setPrimaryForkId(uint256 _forkId) external;
}
