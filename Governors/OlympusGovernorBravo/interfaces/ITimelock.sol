// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.15;

interface ITimelock {
    function delay() external view returns (uint256);

    function GRACE_PERIOD() external view returns (uint256);

    function acceptAdmin() external;

    function queuedTransactions(bytes32 hash) external view returns (bool);

    function queueTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        uint256 proposalId,
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        bytes32 codehash,
        uint256 eta
    ) external payable returns (bytes memory);
}
