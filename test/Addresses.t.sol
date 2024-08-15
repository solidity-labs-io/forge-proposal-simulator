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
        /// whether the address is a contract
        bool isContract;
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

    function test_getAddress() public view {
        address addr = addresses.getAddress("DEPLOYER_EOA");

        assertEq(addr, 0x9679E26bf0C470521DE83Ad77BB1bf1e7312f739);
    }

    function test_getAddressChainId() public view {
        address addr = addresses.getAddress("DEPLOYER_EOA", block.chainid);

        assertEq(addr, 0x9679E26bf0C470521DE83Ad77BB1bf1e7312f739);
    }

    function test_changeAddress() public {
        assertEq(
            addresses.getAddress("DEPLOYER_EOA"),
            0x9679E26bf0C470521DE83Ad77BB1bf1e7312f739,
            "Wrong current address"
        );

        address addr = vm.addr(1);
        addresses.changeAddress("DEPLOYER_EOA", addr, false);

        assertEq(
            addresses.getAddress("DEPLOYER_EOA"),
            addr,
            "Not updated correclty"
        );
    }

    function test_changeAddressToSameAddressFails() public {
        assertEq(
            addresses.getAddress("DEPLOYER_EOA"),
            0x9679E26bf0C470521DE83Ad77BB1bf1e7312f739,
            "Wrong current address"
        );

        address addr = addresses.getAddress("DEPLOYER_EOA");
        vm.expectRevert(
            "Address: DEPLOYER_EOA already set to the same value on chain: 31337"
        );
        addresses.changeAddress("DEPLOYER_EOA", addr, true);
    }

    function test_changeAddressChainId() public {
        assertEq(
            addresses.getAddress("DEPLOYER_EOA"),
            0x9679E26bf0C470521DE83Ad77BB1bf1e7312f739,
            "Wrong current address"
        );
        address addr = vm.addr(1);

        uint256 chainId = 31337;
        addresses.changeAddress("DEPLOYER_EOA", addr, chainId, false);

        assertEq(
            addresses.getAddress("DEPLOYER_EOA", chainId),
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
        addresses.addAddress("DEPLOYER_EOA", addr, chainId, false);

        assertEq(addresses.getAddress("DEPLOYER_EOA", chainId), addr);
        // Validate that the 'DEPLOYER_EOA' address for chain 31337 matches the address from Addresses.json.
        assertEq(
            addresses.getAddress("DEPLOYER_EOA"),
            0x9679E26bf0C470521DE83Ad77BB1bf1e7312f739
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
        addresses.changeAddress("DEPLOYER_EOA", addr, false);
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
        addresses.getAddress("DEPLOYER_EOA", 0);
    }

    function test_reverGetAddressNotSet() public {
        vm.expectRevert("Address: TEST not set on chain: 31337");
        addresses.getAddress("TEST");
    }

    function test_reverGetAddressNotSetOnChain() public {
        vm.expectRevert("Address: DEPLOYER_EOA not set on chain: 666");
        addresses.getAddress("DEPLOYER_EOA", 666);
    }

    function test_revertAddAddressAlreadySet() public {
        vm.expectRevert(
            "Address with name: DEPLOYER_EOA already set on chain: 31337"
        );
        addresses.addAddress("DEPLOYER_EOA", vm.addr(1), false);
    }

    function test_revertAddAddressChainAlreadySet() public {
        vm.expectRevert(
            "Address with name: DEPLOYER_EOA already set on chain: 31337"
        );
        addresses.addAddress("DEPLOYER_EOA", vm.addr(1), 31337, false);
    }

    function test_revertChangedAddressDoesNotExist() public {
        vm.expectRevert(
            "Address: TEST doesn't exist on chain: 31337. Use addAddress instead"
        );
        addresses.changeAddress("TEST", vm.addr(1), false);
    }

    function test_revertDuplicateAddressInJson() public {
        string memory addressesPath = "./addresses/AddressesDuplicated.json";

        vm.expectRevert(
            "Address with name: DEPLOYER_EOA already set on chain: 31337"
        );
        new Addresses(addressesPath);
    }

    function test_addAddressCannotBeZero() public {
        vm.expectRevert("Address cannot be 0");
        addresses.addAddress("DEPLOYER_EOA", address(0), false);
    }

    function test_addAddressCannotBeZeroChainId() public {
        vm.expectRevert("ChainId cannot be 0");
        addresses.addAddress("DEPLOYER_EOA", vm.addr(1), 0, false);
    }

    function test_revertChangeAddressCannotBeZero() public {
        vm.expectRevert("Address cannot be 0");
        addresses.changeAddress("DEPLOYER_EOA", address(0), false);
    }

    function test_revertChangeAddresCannotBeZeroChainId() public {
        vm.expectRevert("ChainId cannot be 0");
        addresses.changeAddress("DEPLOYER_EOA", vm.addr(1), 0, false);
    }

    function test_isContractFalse() public view {
        assertEq(addresses.isAddressContract("DEPLOYER_EOA"), false);
    }

    function test_isContractTrue() public {
        address test = vm.addr(1);

        vm.etch(test, "0x01");

        addresses.addAddress("TEST", test, true);

        assertEq(addresses.isAddressContract("TEST"), true);
    }

    function test_checkAddressFileUpdate() public {
        address test1 = vm.addr(1);

        addresses.addAddress("TEST1", test1, 123, false);

        // update addresses.json file
        addresses.updateJson();

        string memory addressesPath = "./addresses/Addresses.json";
        addresses = new Addresses(addressesPath);

        // check Addresses.json is updated correctly and TEST1 address is set
        addresses.isAddressSet("TEST1");
        assertEq(addresses.getAddress("TEST1", 123), test1);

        test1 = vm.addr(2);
        address test2 = vm.addr(3);

        // change TEST1 address
        addresses.changeAddress("TEST1", test1, 123, false);

        // add TEST2 address
        addresses.addAddress("TEST2", test2, block.chainid, false);

        // update addresses.json file
        addresses.updateJson();

        // update addresses object with updated addresses.json
        addresses = new Addresses(addressesPath);

        // check TEST1 address is updated
        assertEq(addresses.getAddress("TEST1", 123), test1);

        // check TEST2 address is added
        assertEq(addresses.getAddress("TEST2"), test2);
    }

    function addressIsPresent() public {
        address test = vm.addr(1);

        addresses.addAddress("TEST", test, true);

        assertEq(addresses.isAddressSet("TEST"), true);
    }

    function addressIsNotPresent() public view {
        assertEq(addresses.isAddressSet("TEST"), false);
    }

    function addressIsPresentOnChain() public {
        address test = vm.addr(1);

        addresses.addAddress("TEST", test, 123, true);

        assertEq(addresses.isAddressSet("TEST", 123), true);
    }

    function addressIsNotPresentOnChain() public view {
        assertEq(addresses.isAddressSet("DEPLOYER_EOA", 31337), true);
        assertEq(addresses.isAddressSet("DEPLOYER_EOA", 123), false);
    }

    function test_checkAddressRevertIfNotContract() public {
        vm.expectRevert("Address: TEST is not a contract on chain: 31337");
        addresses.addAddress("TEST", vm.addr(1), true);
    }

    function test_checkAddressRevertIfSetIsContractFalseButIsContract() public {
        address test = vm.addr(1);

        vm.etch(test, "0x01");

        vm.expectRevert("Address: TEST is a contract on chain: 31337");
        addresses.addAddress("TEST", test, false);
    }

    function test_revertAddingSameAddressToSameChain() public {
        addressIsPresentOnChain();
        address test = vm.addr(1);

        vm.expectRevert(
            "Address: 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf already set on chain: 123"
        );
        addresses.addAddress("TEST_2", test, 123, false);
    }

    function test_revertDuplicateAddressInJsonWithDifferentName() public {
        string
            memory addressesPath = "./addresses/AddressesDuplicatedDifferentName.json";

        vm.expectRevert(
            "Address: 0x9679E26bf0C470521DE83Ad77BB1bf1e7312f739 already set on chain: 31337"
        );
        new Addresses(addressesPath);
    }
}
