// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Strings.sol)

pragma solidity 0.8.19;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Check if char belongs to string
     */
    function hasChar(
        string memory _string,
        bytes1 delimiter
    ) internal pure returns (bool) {
        bytes memory stringBytes = bytes(_string);

        unchecked {
            for (uint256 i = 0; i < stringBytes.length; i++) {
                if (stringBytes[i] == delimiter) {
                    return true;
                }
            }
        }

        return false;
    }

    function countWords(
        string memory str,
        bytes1 delimiter
    ) public pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        uint256 ctr = 0;

        for (uint256 i = 0; i < strBytes.length; i++) {
            if (
                /// bounds check on i + 1, want to prevent revert on trying to access index that isn't allocated
                (strBytes[i] != delimiter && i + 1 == strBytes.length) ||
                (strBytes[i] != delimiter && strBytes[i + 1] == delimiter)
            ) {
                ctr++;
            }
        }

        return (ctr);
    }

    /// @notice returns an array of strings split by the delimiter
    /// @param str the string to split
    /// @param delimiter the delimiter to split the string by
    function split(
        string memory str,
        bytes1 delimiter
    ) public pure returns (string[] memory) {
        uint256 stringCount = countWords(str, delimiter);

        string[] memory splitStrings = new string[](stringCount);
        bytes memory strBytes = bytes(str);
        uint256 startIndex = 0;
        uint256 splitIndex = 0;

        uint256 i = 0;

        while (i < strBytes.length) {
            if (strBytes[i] == delimiter) {
                splitStrings[splitIndex] = new string(i - startIndex);

                for (uint256 j = startIndex; j < i; j++) {
                    bytes(splitStrings[splitIndex])[j - startIndex] = strBytes[
                        j
                    ];
                }

                while (i < strBytes.length && strBytes[i] == delimiter) {
                    i++;
                }

                splitIndex++;
                startIndex = i;
            }
            i++;
        }

        /// handle final word
        while (i < strBytes.length && strBytes[i] == delimiter) {
            i++;
            startIndex++;
        }

        /// handle the last word
        splitStrings[splitIndex] = new string(strBytes.length - startIndex);

        for (
            uint256 j = startIndex;
            j < strBytes.length && strBytes[j] != delimiter;
            j++
        ) {
            bytes(splitStrings[splitIndex])[j - startIndex] = strBytes[j];
        }

        return splitStrings;
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }
}
