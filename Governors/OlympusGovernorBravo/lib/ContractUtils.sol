// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.15;

library ContractUtils {
    /**
     * @notice Gets the codehash for a given address
     * @param target_ The address to get the codehash for
     * @return The codehash
     */
    function getCodeHash(address target_) internal view returns (bytes32) {
        bytes32 codehash;
        assembly {
            codehash := extcodehash(target_)
        }
        return codehash;
    }
}