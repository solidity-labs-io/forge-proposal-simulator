pragma solidity ^0.8.0;

import {TypeChecker} from "@type-check/TypeChecker.sol";
import {Test} from "forge-std/Test.sol";

contract TypeCheck is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    string public constant TYPE_CHECK_ADDRESSES_PATH =
        "./addresses/TypeCheckAddresses.json";
    TypeChecker public typechecker;

    function setUp() public {
        typechecker = new TypeChecker(
            ADDRESSES_PATH,
            TYPE_CHECK_ADDRESSES_PATH
        );
    }

    function test_nothing() public {
        assertFalse(true);
    }
}
