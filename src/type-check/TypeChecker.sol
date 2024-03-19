pragma solidity ^0.8.0;

import {Addresses} from "@addresses/Addresses.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import {Test} from "@forge-std/Test.sol";
import "@forge-std/console.sol";

contract TypeChecker is Test {
    using Strings for string;

    Addresses public addresses;

    struct SavedTypeCheckAddresses {
        /// Artifact path
        string artifactPath;
        /// Constructor argument for the contract to be checked
        string constructorArgs;
        /// name of contract to store
        string name;
    }

    constructor(
        string memory addressesPath,
        string memory typeCheckAddressesPath
    ) {
        addresses = new Addresses(addressesPath);

        string memory addressesData = string(
            abi.encodePacked(vm.readFile(typeCheckAddressesPath))
        );

        bytes memory parsedJson = vm.parseJson(addressesData);

        SavedTypeCheckAddresses[] memory savedTypeCheckAddresses = abi.decode(
            parsedJson,
            (SavedTypeCheckAddresses[])
        );

        for (uint256 i = 0; i < savedTypeCheckAddresses.length; i++) {
            string[] memory commands = new string[](5);

            /// note to future self, ffi absolutely flips out if you try to set env vars
            commands[0] = "npx";
            commands[1] = "ts-node";
            commands[2] = "typescript/encode.ts";
            commands[3] = savedTypeCheckAddresses[i].constructorArgs;
            commands[4] = savedTypeCheckAddresses[i].artifactPath;

            bytes memory result = vm.ffi(commands);
            console.log("Results :");
            emit log_bytes(result);
        }
    }
}
