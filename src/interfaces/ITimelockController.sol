// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITimelockController {
    function delay() external view returns (uint256);

    function isOperationPending(bytes32) external view returns (bool);

    function isOperationDone(bytes32) external view returns (bool);

    function isOperation(bytes32) external view returns (bool);

    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external view returns (bytes32);

    function getMinDelay() external view returns (uint256);

    function votingDelay() external view returns (uint256);
}
