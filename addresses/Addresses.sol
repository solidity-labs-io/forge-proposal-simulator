/*
Copyright 2023 Lunar Enterprise Ventures, Ltd.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

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
    mapping(string name => mapping(uint256 chainId => Address)) public
        _addresses;

    /// each address on each network should only have 1 name
    /// @notice mapping from address to chain id to whether it exists
    mapping(address addr => mapping(uint256 chainId => bool exist)) public
        addressToChainId;

    /// @notice json structure to store address details
    struct SavedAddresses {
        /// address to store
        address addr;
        /// whether the address is a contract
        bool isContract;
        /// name of contract to store
        string name;
        /// chain id of contract to store
        uint256 chainId;
    }

    /// @notice json structure to read addresses from file
    struct FileAddresses {
        /// address of contract
        address addr;
        /// whether the address is a contract
        bool isContract;
        /// name of contract
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

    /// @notice array of addresses changed during a proposal
    ChangedAddress[] private changedAddresses;

    /// @notice array of all address details
    SavedAddresses[] private savedAddresses;

    /// @notice path of addresses folder
    string private addressesFolderPath;

    /// @notice addresses chain ids
    uint256[] private chainIds;

    constructor(
        string memory _addressesFolderPath,
        uint256[] memory _chainIds
    ) {
        addressesFolderPath = _addressesFolderPath;
        for (uint256 i; i < _chainIds.length; ++i) {
            chainIds.push(_chainIds[i]);

            string memory addressesPath = string(
                abi.encodePacked(
                    _addressesFolderPath,
                    "/",
                    vm.toString(_chainIds[i]),
                    ".json"
                )
            );

            string memory addressesData =
                string(abi.encodePacked(vm.readFile(addressesPath)));

            bytes memory parsedJson = vm.parseJson(addressesData);

            FileAddresses[] memory fileAddresses =
                abi.decode(parsedJson, (FileAddresses[]));

            for (uint256 j = 0; j < fileAddresses.length; j++) {
                _addAddress(
                    fileAddresses[j].name,
                    fileAddresses[j].addr,
                    _chainIds[i],
                    fileAddresses[j].isContract
                );
            }
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
    function getAddress(string memory name, uint256 _chainId)
        public
        view
        returns (address)
    {
        return _getAddress(name, _chainId);
    }

    /// @notice add an address for the current chainId
    /// @param name the name of the address
    /// @param addr the address to add
    /// @param isContract whether the address is a contract
    function addAddress(string memory name, address addr, bool isContract)
        public
    {
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

        recordedAddresses.push(RecordedAddress({name: name, chainId: _chainId}));
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
            ChangedAddress({name: name, chainId: chainId, oldAddress: data.addr})
        );

        for (uint256 i; i < savedAddresses.length; i++) {
            if (
                keccak256(abi.encode(savedAddresses[i].name))
                    == keccak256(abi.encode(name))
                    && savedAddresses[i].chainId == chainId
            ) {
                savedAddresses[i].addr = _addr;
            }
        }

        data.addr = _addr;
        data.isContract = isContract;
        vm.label(_addr, name);
    }

    /// @notice change an address for the current chainId
    /// @param name the name of the address
    /// @param addr the address to change to
    /// @param isContract whether the address is a contract
    function changeAddress(string memory name, address addr, bool isContract)
        public
    {
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
            uint256[] memory chainIdsList,
            address[] memory addresses
        )
    {
        uint256 length = recordedAddresses.length;
        names = new string[](length);
        chainIdsList = new uint256[](length);
        addresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            names[i] = recordedAddresses[i].name;
            chainIdsList[i] = recordedAddresses[i].chainId;
            addresses[i] = _addresses[recordedAddresses[i].name][recordedAddresses[i]
                .chainId].addr;
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
            uint256[] memory chainIdsList,
            address[] memory oldAddresses,
            address[] memory newAddresses
        )
    {
        uint256 length = changedAddresses.length;
        names = new string[](length);
        chainIdsList = new uint256[](length);
        oldAddresses = new address[](length);
        newAddresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            names[i] = changedAddresses[i].name;
            chainIdsList[i] = changedAddresses[i].chainId;
            oldAddresses[i] = changedAddresses[i].oldAddress;
            newAddresses[i] = _addresses[changedAddresses[i].name][changedAddresses[i]
                .chainId].addr;
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
    function isAddressSet(string memory name, uint256 chainId)
        public
        view
        returns (bool)
    {
        return _addresses[name][chainId].addr != address(0);
    }

    /// @dev Print new recorded and changed addresses
    function printJSONChanges() external view {
        {
            (string[] memory names,, address[] memory addresses) =
                getRecordedAddresses();

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
            (string[] memory names,,, address[] memory addresses) =
                getChangedAddresses();

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

    /// @dev Update Address json
    function updateJson() external {
        for (uint256 i; i < chainIds.length; ++i) {
            string memory json = _constructJson(chainIds[i]);
            string memory addressesPath = string(
                abi.encodePacked(
                    addressesFolderPath, "/", vm.toString(chainIds[i]), ".json"
                )
            );
            vm.writeJson(json, addressesPath);
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
                    vm.toString(addr),
                    " already set on chain: ",
                    vm.toString(chainId)
                )
            )
        );

        addressToChainId[addr][chainId] = true;

        _checkAddress(addr, isContract, name, chainId);

        currentAddress.addr = addr;
        currentAddress.isContract = isContract;

        savedAddresses.push(
            SavedAddresses({
                name: name,
                addr: addr,
                chainId: chainId,
                isContract: isContract
            })
        );

        vm.label(addr, name);
    }

    /// @notice get an address for a specific chainId
    /// @param name the name of the address
    /// @param chainId the chain id
    function _getAddress(string memory name, uint256 chainId)
        private
        view
        returns (address addr)
    {
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

    /// @notice constructs json string data for address json from saved addresses array
    /// @param chainId chain id of addresses
    function _constructJson(uint256 chainId)
        private
        view
        returns (string memory)
    {
        string memory json = "[";

        for (uint256 i = 0; i < savedAddresses.length; ++i) {
            if (savedAddresses[i].chainId == chainId) {
                json = string(
                    abi.encodePacked(
                        json,
                        "{",
                        '"addr": "',
                        vm.toString(savedAddresses[i].addr),
                        '",',
                        '"name": "',
                        savedAddresses[i].name,
                        '",',
                        '"isContract": ',
                        savedAddresses[i].isContract ? "true" : "false",
                        "}"
                    )
                );

                json = string(abi.encodePacked(json, ","));
            }
        }

        json = _removeLastCharacter(json);

        json = string(abi.encodePacked(json, "]"));

        return json;
    }

    function _removeLastCharacter(string memory str)
        public
        pure
        returns (string memory)
    {
        bytes memory strBytes = bytes(str);

        // Create a new bytes array with one less byte
        bytes memory newStrBytes = new bytes(strBytes.length - 1);

        // Copy bytes from original string except the last one
        for (uint256 i = 0; i < newStrBytes.length; i++) {
            newStrBytes[i] = strBytes[i];
        }

        return string(newStrBytes);
    }
}
