// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Strings} from "@utils/Strings.sol";

contract TestAddresses is Test {
    Addresses addresses; 

    bytes parsedJson;

    /// @notice json structure to read addresses into storage from file
    struct SavedAddresses {
        /// address to store
        address addr;
        /// chain id of network to store for
        uint256 chainId;
        /// name of contract to store
        string name;
    }

    function setUp() public {
	string memory addressesPath = "./addresses/Addresses.json";
	addresses = new Addresses(addressesPath);

        string memory addressesData = string(abi.encodePacked(vm.readFile(addressesPath)));
        parsedJson = vm.parseJson(addressesData);
    }

    function test_getAddress() public {
	address addr = addresses.getAddress("DEV_MULTISIG");

	assertEq(addr, 0x3dd46846eed8D147841AE162C8425c08BD8E1b41);
    }

    function test_getAddressChainId() public {
	address addr = addresses.getAddress("TEAM_MULTISIG", block.chainid);

	assertEq(addr, 0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9);
    }

    function test_addAddress() public {
	address addr = vm.addr(1);
	addresses.addAddress("TEST", addr);

	assertEq(addresses.getAddress("TEST"), addr);
    }

    function test_addAddressChainId() public {
	address addr = vm.addr(1);
	uint256 chainId = 123;
	addresses.addAddress("TEST", chainId, addr);

	assertEq(addresses.getAddress("TEST", chainId), addr);
    }

    function test_addAddressDifferentChain() public {
	address addr = vm.addr(1);
	uint256 chainId = 123;
	addresses.addAddress("DEV_MULTISIG", chainId, addr);

	assertEq(addresses.getAddress("DEV_MULTISIG", chainId), addr);
	// Validate that the 'DEV_MULTISIG' address for chain 31337 matches the address from Addresses.json.
	assertEq(addresses.getAddress("DEV_MULTISIG"), 0x3dd46846eed8D147841AE162C8425c08BD8E1b41);
    }

    function test_resetRecordingAddresses() public {
	addresses.resetRecordingAddresses();

	(string[] memory names, uint256[] memory chainIds, address[] memory _addresses) = addresses.getRecordedAddresses();

	assertEq(names.length, 0);
	assertEq(chainIds.length, 0);
	assertEq(_addresses.length, 0);

        vm.expectRevert(bytes("Address: DEV_MULTISIG not set on chain: 31337"));
	addresses.getAddress("DEV_MULTISIG");
    }

    function test_getRecordingAddresses() public {
	(string[] memory names, uint256[] memory chainIds, address[] memory _addresses) = addresses.getRecordedAddresses();

	assertEq(names.length, 4);
	assertEq(chainIds.length, 4);
	assertEq(_addresses.length, 4);

        SavedAddresses[] memory savedAddresses = abi.decode(parsedJson, (SavedAddresses[]));

	for(uint256 i = 0; i < savedAddresses.length; i++) {
	    assertEq(names[i], savedAddresses[i].name);
	    assertEq(chainIds[i], savedAddresses[i].chainId);
	    assertEq(_addresses[i], savedAddresses[i].addr);
	}
    }

    function test_revertGetAddressChainZero() public {
	vm.expectRevert(bytes("ChainId cannot be 0"));
	addresses.getAddress("DEV_MULTISIG", 0);
    }

    function test_reverGetAddressNotSet() public {
	vm.expectRevert(bytes("Address: TEST not set on chain: 31337"));
	addresses.getAddress("TEST");

    }

    function test_reverGetAddressNotSetOnChain() public {
	vm.expectRevert(bytes("Address: DEV_MULTISIG not set on chain: 666"));
	addresses.getAddress("DEV_MULTISIG", 666);
    }

    function test_revertAddAddressAlreadySet() public {
	vm.expectRevert(bytes("Address: DEV_MULTISIG already set on chain: 31337"));
	addresses.addAddress("DEV_MULTISIG", vm.addr(1));
    }

    function test_revertAddAddressChainAlreadySet() public {
	vm.expectRevert(bytes("Address: DEV_MULTISIG already set on chain: 31337"));
	addresses.addAddress("DEV_MULTISIG", 31337,  vm.addr(1));
    }

}
