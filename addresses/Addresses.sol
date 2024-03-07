
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";
import {IAddresses} from "@addresses/IAddresses.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";

/// @notice This is a contract that stores addresses for different networks.
/// It allows a project to have a single source of truth to get all the addresses
/// for a given network.
contract Addresses is IAddresses, Test {
    using Strings for uint256;
    
    struct Address {
        address addr;
        bool isContract;
    }

    /// @notice mapping from contract name to network chain id to address
    mapping(string name => mapping(uint256 chainId => Address))
        public _addresses;

    /// @notice chainid of the network when contract is constructed
    uint256 public immutable chainId;

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

    /// @notice struct to record addresses deployed during a proposal
    struct RecordedAddress {
        string name;
        uint256 chainId;
    }

    // @notice struct to record addresses changed during a proposal
    struct ChangedAddress {
        string name;
        uint256 chainId;
        address oldAddress;
    }

    /// @notice array of addresses deployed during a proposal
    RecordedAddress[] private recordedAddresses;

    // @notice array of addresses changed during a proposal
    ChangedAddress[] private changedAddresses;

    constructor(string memory addressesPath) {
        chainId = block.chainid;

        string memory addressesData = string(
            abi.encodePacked(vm.readFile(addressesPath))
        );

        bytes memory parsedJson = vm.parseJson(addressesData);

        SavedAddresses[] memory savedAddresses = abi.decode(
            parsedJson,
            (SavedAddresses[])
        );

        for (uint256 i = 0; i < savedAddresses.length; i++) {
            _addAddress(
                savedAddresses[i].name,
                savedAddresses[i].addr,
                savedAddresses[i].chainId,
                savedAddresses[i].isContract
            );
        }
    }

    /// @notice add an address for a specific chainId
    function _addAddress(
        string memory name,
        address addr,
        uint256 _chainId,
        bool isContract
    ) private {
        Address storage currentAddress = _addresses[name][_chainId];
        currentAddress = _addresses[name][_chainId];

        require(addr != address(0), "Address cannot be 0");

        require(_chainId != 0, "ChainId cannot be 0");

        require(
            currentAddress.addr == address(0),
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " already set on chain: ",
                    _chainId.toString()
                )
            )
        );

        _checkAddress(addr, isContract, name, _chainId);

        currentAddress.addr = addr;
        currentAddress.isContract = isContract;

        vm.label(addr, name);
    }

    function _getAddress(
        string memory name,
        uint256 _chainId
    ) private view returns (address addr) {
        require(_chainId != 0, "ChainId cannot be 0");

        Address memory data = _addresses[name][_chainId];
        addr = data.addr;

        require(
            addr != address(0),
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " not set on chain: ",
                    _chainId.toString()
                )
            )
        );
    }

    /// @notice get an address for the current chainId
    function getAddress(string memory name) public view returns (address) {
        return _getAddress(name, chainId);
    }

    /// @notice get an address for a specific chainId
    function getAddress(
        string memory name,
        uint256 _chainId
    ) public view returns (address) {
        return _getAddress(name, _chainId);

    }

    /// @notice add an address for the current chainId
    function addAddress(string memory name, address addr, bool isContract) public {
        _addAddress(name, addr, chainId, isContract);

        recordedAddresses.push(RecordedAddress({name: name, chainId: chainId}));
    }

    /// @notice add an address for a specific chainId
    function addAddress(
        string memory name,
        address addr,
        uint256 _chainId,
        bool isContract
    ) public {
        _addAddress(name, addr, _chainId, isContract);

        recordedAddresses.push(
            RecordedAddress({name: name, chainId: _chainId})
        );
    }

    /// @notice change an address for a specific chainId
    function changeAddress(
        string memory name,
        address _addr,
        uint256 _chainId,
        bool isContract
    ) public {
        Address storage data = _addresses[name][_chainId];

        require(_addr != address(0), "Address cannot be 0");

        require(_chainId != 0, "ChainId cannot be 0");

        require(
            data.addr != address(0),
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " doesn't exist on chain: ",
                    _chainId.toString(),
                    ". Use addAddress instead"
                )
            )
        );

        require(
            data.addr != _addr,
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " already set to the same value on chain: ",
                    _chainId.toString()
                )
            )
        );

        _checkAddress(_addr, isContract, name, _chainId);

        changedAddresses.push(
            ChangedAddress({name: name, chainId: _chainId, oldAddress: data.addr})
        );

        data.addr = _addr;
        data.isContract = isContract;
        vm.label(_addr, name);
    }

    /// @notice change an address for the current chainId
    function changeAddress(string memory name, address addr, bool isContract) public {
        changeAddress(name, addr, chainId, isContract);
    }

    /// @notice remove recorded addresses
    function resetRecordingAddresses() external {
        delete recordedAddresses;
    }

    /// @notice get recorded addresses from a proposal's deployment
    function getRecordedAddresses()
        external
        view
        returns (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory addresses
        )
    {
        uint256 length = recordedAddresses.length;
        names = new string[](length);
        chainIds = new uint256[](length);
        addresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            names[i] = recordedAddresses[i].name;
            chainIds[i] = recordedAddresses[i].chainId;
            addresses[i] = _addresses[recordedAddresses[i].name][
                recordedAddresses[i].chainId
            ].addr;
        }
    }

    /// @notice remove changed addresses
    function resetChangedAddresses() external {
        delete changedAddresses;
    }

    /// @notice get changed addresses from a proposal's deployment
    function getChangedAddresses()
        external
        view
        returns (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory oldAddresses,
            address[] memory newAddresses
        )
    {
        uint256 length = changedAddresses.length;
        names = new string[](length);
        chainIds = new uint256[](length);
        oldAddresses = new address[](length);
        newAddresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            names[i] = changedAddresses[i].name;
            chainIds[i] = changedAddresses[i].chainId;
            oldAddresses[i] = changedAddresses[i].oldAddress;
            newAddresses[i] = _addresses[changedAddresses[i].name][
                changedAddresses[i].chainId
            ].addr;
        }
    }

    function isContract(string memory name) public view returns (bool) {
        return _addresses[name][chainId].isContract;
    }

    function addressIsSet(string memory name) public view returns (bool) {
        return _addresses[name][chainId].addr != address(0);
    }

    function addressIsSet(string memory name, uint256 _chainId)
        public
        view
        returns (bool)
    {
        return _addresses[name][_chainId].addr != address(0);
    }

    function _checkAddress(
        address _addr,
        bool isContract,
        string memory name,
        uint256 _chainId
    ) private view {
        if (_chainId == block.chainid) {
            if (isContract) {
                require(
                    _addr.code.length > 0,
                    string(
                        abi.encodePacked(
                            "Address: ",
                            name,
                            " is not a contract on chain: ",
                            _chainId.toString()
                        )
                    )
                );
            } else {
                require(
                    _addr.code.length == 0,
                    string(
                        abi.encodePacked(
                            "Address: ",
                            name,
                            " is a contract on chain: ",
                            _chainId.toString()
                        )
                    )
                );
            }
        }
    }
}
