// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract TestAddresses is Test {
    Addresses public addresses;

    bytes public parsedJson;

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

        string memory addressesData = string(
            abi.encodePacked(vm.readFile(addressesPath))
        );
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

    function test_changeAddress() public {
        assertEq(
            addresses.getAddress("DEV_MULTISIG"),
            0x3dd46846eed8D147841AE162C8425c08BD8E1b41,
            "Wrong current address"
        );

        address addr = vm.addr(1);
        addresses.changeAddress("DEV_MULTISIG", addr, false);

        assertEq(
            addresses.getAddress("DEV_MULTISIG"),
            addr,
            "Not updated correclty"
        );
    }

    function test_changeAddressToSameAddressFails() public {
        assertEq(
            addresses.getAddress("DEV_MULTISIG"),
            0x3dd46846eed8D147841AE162C8425c08BD8E1b41,
            "Wrong current address"
        );

        address addr = addresses.getAddress("DEV_MULTISIG");
        vm.expectRevert(
            "Address: DEV_MULTISIG already set to the same value on chain: 31337"
        );
        addresses.changeAddress("DEV_MULTISIG", addr, true);
    }

    function test_changeAddressChainId() public {
        assertEq(
            addresses.getAddress("DEV_MULTISIG"),
            0x3dd46846eed8D147841AE162C8425c08BD8E1b41,
            "Wrong current address"
        );
        address addr = vm.addr(1);

        uint256 chainId = 31337;
        addresses.changeAddress("DEV_MULTISIG", addr, chainId, false);

        assertEq(
            addresses.getAddress("DEV_MULTISIG", chainId),
            addr,
            "Not updated correclty"
        );
    }

    function test_addAddress() public {
        address addr = vm.addr(1);
        addresses.addAddress("TEST", addr, false);

        assertEq(addresses.getAddress("TEST"), addr);
    }

    function test_addAddressChainId() public {
        address addr = vm.addr(1);
        uint256 chainId = 123;
        addresses.addAddress("TEST", addr, chainId, false);

        assertEq(addresses.getAddress("TEST", chainId), addr);
    }

    function test_addAddressDifferentChain() public {
        address addr = vm.addr(1);
        uint256 chainId = 123;
        addresses.addAddress("DEV_MULTISIG", addr, chainId, false);

        assertEq(addresses.getAddress("DEV_MULTISIG", chainId), addr);
        // Validate that the 'DEV_MULTISIG' address for chain 31337 matches the address from Addresses.json.
        assertEq(
            addresses.getAddress("DEV_MULTISIG"),
            0x3dd46846eed8D147841AE162C8425c08BD8E1b41
        );
    }

    function test_resetRecordingAddresses() public {
        addresses.resetRecordingAddresses();

        (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory _addresses
        ) = addresses.getRecordedAddresses();

        assertEq(names.length, 0);
        assertEq(chainIds.length, 0);
        assertEq(_addresses.length, 0);
    }

    function test_getRecordingAddresses() public {
        // Add a new address
        address addr = vm.addr(1);
        addresses.addAddress("TEST", addr, false);

        (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory _addresses
        ) = addresses.getRecordedAddresses();

        assertEq(names.length, 1);
        assertEq(chainIds.length, 1);
        assertEq(_addresses.length, 1);

        assertEq(names[0], "TEST");
        assertEq(chainIds[0], 31337);
        assertEq(_addresses[0], addr);
    }

    function test_resetChangedAddresses() public {
        addresses.resetChangedAddresses();

        (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory oldAddresses,
            address[] memory newAddresses
        ) = addresses.getChangedAddresses();

        assertEq(names.length, 0);
        assertEq(chainIds.length, 0);
        assertEq(oldAddresses.length, 0);
        assertEq(newAddresses.length, 0);
    }

    function test_getChangedAddresses() public {
        address addr = vm.addr(1);
        addresses.changeAddress("DEV_MULTISIG", addr, false);
        (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory oldAddresses,
            address[] memory newAddresses
        ) = addresses.getChangedAddresses();

        assertEq(names.length, 1);
        assertEq(chainIds.length, 1);
        assertEq(oldAddresses.length, 1);
        assertEq(newAddresses.length, 1);

        SavedAddresses[] memory savedAddresses = abi.decode(
            parsedJson,
            (SavedAddresses[])
        );

        assertEq(names[0], savedAddresses[0].name);
        assertEq(chainIds[0], savedAddresses[0].chainId);
        assertEq(oldAddresses[0], savedAddresses[0].addr);
        assertEq(newAddresses[0], addr);
    }

    function test_revertGetAddressChainZero() public {
        vm.expectRevert("ChainId cannot be 0");
        addresses.getAddress("DEV_MULTISIG", 0);
    }

    function test_reverGetAddressNotSet() public {
        vm.expectRevert("Address: TEST not set on chain: 31337");
        addresses.getAddress("TEST");
    }

    function test_reverGetAddressNotSetOnChain() public {
        vm.expectRevert("Address: DEV_MULTISIG not set on chain: 666");
        addresses.getAddress("DEV_MULTISIG", 666);
    }

    function test_revertAddAddressAlreadySet() public {
        vm.expectRevert("Address: DEV_MULTISIG already set on chain: 31337");
        addresses.addAddress("DEV_MULTISIG", vm.addr(1), false);
    }

    function test_revertAddAddressChainAlreadySet() public {
        vm.expectRevert("Address: DEV_MULTISIG already set on chain: 31337");
        addresses.addAddress("DEV_MULTISIG", vm.addr(1), 31337, false);
    }

    function test_revertChangedAddressDoesNotExist() public {
        vm.expectRevert(
            "Address: TEST doesn't exist on chain: 31337. Use addAddress instead"
        );
        addresses.changeAddress("TEST", vm.addr(1), false);
    }

    function test_revertDuplicateAddressInJson() public {
        string memory addressesPath = "./addresses/AddressesDuplicated.json";

        vm.expectRevert("Address: DEV_MULTISIG already set on chain: 31337");
        new Addresses(addressesPath);
    }
}
