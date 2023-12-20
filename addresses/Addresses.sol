// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {IAddresses} from "@addresses/IAddresses.sol";
import {Strings} from "@utils/Strings.sol";

/// @notice This is a contract that stores addresses for different networks.
/// It allows a project to have a single source of truth to get all the addresses
/// for a given network.
contract Addresses is IAddresses, Test {
    using Strings for uint256;

    /// @notice mapping from contract name to network chain id to address
    mapping(string name => mapping(uint256 chainId => address addr)) public _addresses;

    /// @notice chainid of the network when contract is constructed
    uint256 public immutable chainId;

    /// @notice json structure to read addresses into storage from file
    struct SavedAddresses {
        /// address to store
        address addr;
        /// chain id of network to store for
        uint256 chainId;
        /// name of contract to store
        string name;
    }

    /// @notice struct to record addresses deployed during a proposal
    struct RecordedAddress {
        string name;
        uint256 chainId;
    }

    /// @notice array of addresses deployed during a proposal
    RecordedAddress[] private recordedAddresses;

    constructor(string memory addressesPath) {
        chainId = block.chainid;

        string memory addressesData = string(abi.encodePacked(vm.readFile(addressesPath)));

        bytes memory parsedJson = vm.parseJson(addressesData);

        SavedAddresses[] memory savedAddresses = abi.decode(parsedJson, (SavedAddresses[]));

	for (uint256 i = 0; i < savedAddresses.length; i++) {
            _addAddress(savedAddresses[i].name, savedAddresses[i].chainId, savedAddresses[i].addr);
        }
    }

    /// @notice add an address for a specific chainId
    function _addAddress(string memory name, uint256 _chainId, address addr) private {
        address currentAddress = _addresses[name][_chainId];

        require(
            currentAddress == address(0),
            string(abi.encodePacked("Address: ", name, " already set on chain: ", _chainId.toString()))
        );

        _addresses[name][_chainId] = addr;
        vm.label(addr, name);

        recordedAddresses.push(RecordedAddress({name: name, chainId: _chainId}));
    }

    function _getAddress(string memory name, uint256 _chainId) private view returns (address addr) {
        require(_chainId != 0, "ChainId cannot be 0");

        addr = _addresses[name][_chainId];

        require(
            addr != address(0),
            string(abi.encodePacked("Address: ", name, " not set on chain: ", _chainId.toString()))
        );
    }

    /// @notice get an address for the current chainId
    function getAddress(string memory name) public view returns (address) {
        return _getAddress(name, chainId);
    }

    /// @notice get an address for a specific chainId
    function getAddress(string memory name, uint256 _chainId) public view returns (address) {
        return _getAddress(name, _chainId);
    }

    /// @notice add an address for the current chainId
    function addAddress(string memory name, address addr) public {
        _addAddress(name, chainId, addr);
    }

    /// @notice add an address for a specific chainId
    function addAddress(string memory name, uint256 _chainId, address addr) public {
        _addAddress(name, _chainId, addr);
    }

    /// @notice remove recorded addresses
    function resetRecordingAddresses() external {
        for (uint256 i = 0; i < recordedAddresses.length; i++) {
            delete _addresses[recordedAddresses[i].name][recordedAddresses[i].chainId];
        }

        delete recordedAddresses;
    }

    /// @notice get recorded addresses from a proposal's deployment
    function getRecordedAddresses() external view returns (string[] memory names, uint256[] memory chainIds, address[] memory addresses) {
	uint256 length = recordedAddresses.length;
        names = new string[](length);
	chainIds = new uint256[](length);
        addresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            names[i] = recordedAddresses[i].name;
	    chainIds[i] = recordedAddresses[i].chainId;
            addresses[i] = _addresses[recordedAddresses[i].name][recordedAddresses[i].chainId];
        }
    }
}
