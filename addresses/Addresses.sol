// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {console} from "@forge-std/console.sol";
import {Test} from "@forge-std/Test.sol";
import {IAddresses} from "@addresses/IAddresses.sol";

/// @notice This is a contract that stores addresses for different networks.
/// It allows a project to have a single source of truth to get all the addresses
/// for a given network.
contract Addresses is IAddresses, Test {
    struct Address {
        address addr;
        bool isContract;
    }

    /// @notice mapping from contract name to network chain id to address
    mapping(string name => mapping(uint256 chainId => Address))
        public _addresses;

    /// each address on each network should only have 1 name
    /// @notice mapping from address to chain id to whether it exists
    mapping(address addr => mapping(uint256 chainId => bool exist))
        public addressToChainId;

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

    /// @notice get an address for the current chainId
    /// @param name the name of the address
    function getAddress(string memory name) public view returns (address) {
        return _getAddress(name, block.chainid);
    }

    /// @notice get an address for a specific chainId
    /// @param name the name of the address
    /// @param _chainId the chain id
    function getAddress(
        string memory name,
        uint256 _chainId
    ) public view returns (address) {
        return _getAddress(name, _chainId);
    }

    /// @notice add an address for the current chainId
    /// @param name the name of the address
    /// @param addr the address to add
    /// @param isContract whether the address is a contract
    function addAddress(
        string memory name,
        address addr,
        bool isContract
    ) public {
        _addAddress(name, addr, block.chainid, isContract);

        recordedAddresses.push(
            RecordedAddress({name: name, chainId: block.chainid})
        );
    }

    /// @notice add an address for a specific chainId
    /// @param name the name of the address
    /// @param addr the address to add
    /// @param _chainId the chain id
    /// @param isContract whether the address is a contract
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
    /// @param name the name of the address
    /// @param _addr the address to change to
    /// @param chainId the chain id
    /// @param isContract whether the address is a contract
    function changeAddress(
        string memory name,
        address _addr,
        uint256 chainId,
        bool isContract
    ) public {
        Address storage data = _addresses[name][chainId];

        require(_addr != address(0), "Address cannot be 0");

        require(chainId != 0, "ChainId cannot be 0");

        require(
            data.addr != address(0),
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " doesn't exist on chain: ",
                    vm.toString(chainId),
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
                    vm.toString(chainId)
                )
            )
        );

        _checkAddress(_addr, isContract, name, chainId);

        changedAddresses.push(
            ChangedAddress({
                name: name,
                chainId: chainId,
                oldAddress: data.addr
            })
        );

        data.addr = _addr;
        data.isContract = isContract;
        vm.label(_addr, name);
    }

    /// @notice change an address for the current chainId
    /// @param name the name of the address
    /// @param addr the address to change to
    /// @param isContract whether the address is a contract
    function changeAddress(
        string memory name,
        address addr,
        bool isContract
    ) public {
        changeAddress(name, addr, block.chainid, isContract);
    }

    /// @notice remove recorded addresses
    function resetRecordingAddresses() external {
        delete recordedAddresses;
    }

    /// @notice get recorded addresses from a proposal's deployment
    function getRecordedAddresses()
        public
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
        public
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

    /// @notice check if an address is a contract
    /// @param name the name of the address
    function isAddressContract(string memory name) public view returns (bool) {
        return _addresses[name][block.chainid].isContract;
    }

    /// @notice check if an address is set
    /// @param name the name of the address
    function isAddressSet(string memory name) public view returns (bool) {
        return _addresses[name][block.chainid].addr != address(0);
    }

    /// @notice check if an address is set for a specific chain id
    /// @param name the name of the address
    /// @param chainId the chain id
    function isAddressSet(
        string memory name,
        uint256 chainId
    ) public view returns (bool) {
        return _addresses[name][chainId].addr != address(0);
    }

    /// @dev Print recorded addresses
    function printRecordedAddresses() external view {
        {
            (
                string[] memory names,
                ,
                address[] memory addresses
            ) = getRecordedAddresses();

            if (names.length > 0) {
                console.log("\n\n--------- Addresses added ---------");
                for (uint256 j = 0; j < names.length; j++) {
                    console.log("{\n          'addr': '%s', ", addresses[j]);
                    console.log("        'chainId': %d,", block.chainid);
                    console.log("        'isContract': %s", true, ",");
                    console.log(
                        "        'name': '%s'\n}%s",
                        names[j],
                        j < names.length - 1 ? "," : ""
                    );
                }
            }
        }

        {
            (
                string[] memory names,
                ,
                ,
                address[] memory addresses
            ) = getChangedAddresses();

            if (names.length > 0) {
                console.log("\n\n-------- Addresses changed  --------");

                for (uint256 j = 0; j < names.length; j++) {
                    console.log("{\n          'addr': '%s', ", addresses[j]);
                    console.log("        'chainId': %d,", block.chainid);
                    console.log("        'isContract': %s", true, ",");
                    console.log(
                        "        'name': '%s'\n}%s",
                        names[j],
                        j < names.length - 1 ? "," : ""
                    );
                }
            }
        }
    }

    /// @notice add an address for a specific chainId
    /// @param name the name of the address
    /// @param addr the address to add
    /// @param chainId the chain id
    /// @param isContract whether the address is a contract
    function _addAddress(
        string memory name,
        address addr,
        uint256 chainId,
        bool isContract
    ) private {
        Address storage currentAddress = _addresses[name][chainId];

        require(addr != address(0), "Address cannot be 0");

        require(chainId != 0, "ChainId cannot be 0");

        require(
            currentAddress.addr == address(0),
            string(
                abi.encodePacked(
                    "Address with name: ",
                    name,
                    " already set on chain: ",
                    vm.toString(chainId)
                )
            )
        );

        bool exist = addressToChainId[addr][chainId];

        require(
            !exist,
            string(
                abi.encodePacked(
                    "Address: ",
                    addressToString(addr),
                    " already set on chain: ",
                    vm.toString(chainId)
                )
            )
        );

        addressToChainId[addr][chainId] = true;

        _checkAddress(addr, isContract, name, chainId);

        currentAddress.addr = addr;
        currentAddress.isContract = isContract;

        vm.label(addr, name);
    }

    /// @notice get an address for a specific chainId
    /// @param name the name of the address
    /// @param chainId the chain id
    function _getAddress(
        string memory name,
        uint256 chainId
    ) private view returns (address addr) {
        require(chainId != 0, "ChainId cannot be 0");

        Address memory data = _addresses[name][chainId];
        addr = data.addr;

        require(
            addr != address(0),
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " not set on chain: ",
                    vm.toString(chainId)
                )
            )
        );
    }

    /// @notice check if an address is a contract
    /// @param _addr the address to check
    /// @param isContract whether the address is a contract
    /// @param name the name of the address
    /// @param chainId the chain id
    function _checkAddress(
        address _addr,
        bool isContract,
        string memory name,
        uint256 chainId
    ) private view {
        if (chainId == block.chainid) {
            if (isContract) {
                require(
                    _addr.code.length > 0,
                    string(
                        abi.encodePacked(
                            "Address: ",
                            name,
                            " is not a contract on chain: ",
                            vm.toString(chainId)
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
                            vm.toString(chainId)
                        )
                    )
                );
            }
        }
    }

    function addressToString(
        address _addr
    ) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes20 value = bytes20(_addr);
        bytes memory str = new bytes(40); // An Ethereum address has 20 bytes, hence 40 characters in hex
        for (uint256 i = 0; i < 20; i++) {
            str[i * 2] = alphabet[uint8(value[i] >> 4)];
            str[1 + i * 2] = alphabet[uint8(value[i] & 0x0f)];
        }
        return string(abi.encodePacked("0x", str));
    }
}
