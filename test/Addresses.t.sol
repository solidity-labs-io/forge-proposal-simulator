// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {console} from "@forge-std/console.sol";
import {Test} from "@forge-std/Test.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Strings} from "@utils/Strings.sol";

contract TestAddresses is Test {
    Addresses addresses; 

    function setUp() public {
	addresses = new Addresses("./addresses/Addresses.json");
    }

    function test_getAddress() public {
	address addr = addresses.getAddress("DEV_MULTISIG");

	assertEq(addr, 0x3dd46846eed8D147841AE162C8425c08BD8E1b41);
    }

    function test_getAddressChainId() public {
	address addr = addresses.getAddress("TEAM_MULTISIG", block.chainid);

	assertEq(addr, 0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9);
    }

}
