pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {TypeChecker} from "@type-check/TypeChecker.sol";

contract TypeCheck is Script {
    string public ADDRESSES_PATH = vm.envString("ADDRESSES_PATH");
    string public TYPE_CHECK_ADDRESSES_PATH =
        vm.envString("TYPE_CHECK_ADDRESSES_PATH");
    string public LIB_PATH =
        vm.envOr("LIB_PATH", string("lib/forge-proposal-simulator/"));

    function run() public virtual {
        new TypeChecker(ADDRESSES_PATH, TYPE_CHECK_ADDRESSES_PATH, LIB_PATH);
    }
}
