pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {TypeChecker} from "@type-check/TypeChecker.sol";

contract TypeCheck is Script {
    string public constant ADDRESSES_PATH = "../../addresses/Addresses.json";
    string public constant TYPE_CHECK_ADDRESSES_PATH =
        "../../addresses/TypeCheckAddresses.json";
    string public constant ARTIFACT_PATH = "../../out/";
    function run() public virtual {
        new TypeChecker(
            ADDRESSES_PATH,
            TYPE_CHECK_ADDRESSES_PATH,
            ARTIFACT_PATH
        );
    }
}
