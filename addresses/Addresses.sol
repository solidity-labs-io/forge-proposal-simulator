pragma solidity ^0.8.0;

import {console} from "@forge-std/console.sol";
import {Vm} from "@forge-std/Vm.sol";
import {IAddresses} from "@addresses/IAddresses.sol";

/// @notice This is a contract that stores addresses for different networks.
/// It allows a project to have a single source of truth to get all the addresses
/// for a given network.
contract Addresses is IAddresses {
    Vm private constant forgeVm =
        Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct RegistryRecord {
        address location;
        bool hasCode;
    }

    struct PersistedRecord {
        address location;
        bool hasCode;
        string label;
        uint256 network;
    }

    struct DiskRecord {
        address location;
        bool hasCode;
        string label;
    }

    struct AddedMarker {
        string label;
        uint256 network;
    }

    struct ReplacedMarker {
        string label;
        uint256 network;
        address priorLocation;
    }

    mapping(string label => mapping(uint256 network => RegistryRecord)) private
        registry;

    mapping(address location => mapping(uint256 network => bool present))
        private reverseRegistry;

    AddedMarker[] private additions;
    ReplacedMarker[] private replacements;
    PersistedRecord[] private persisted;
    string private rootDirectory;
    uint256[] private knownNetworks;

    constructor(string memory folder, uint256[] memory networks) {
        rootDirectory = folder;

        for (uint256 cursor; cursor < networks.length; ++cursor) {
            uint256 network = networks[cursor];
            knownNetworks.push(network);

            string memory document = string(
                abi.encodePacked(
                    folder, "/", forgeVm.toString(network), ".json"
                )
            );

            string memory contents =
                string(abi.encodePacked(forgeVm.readFile(document)));
            DiskRecord[] memory rows =
                abi.decode(forgeVm.parseJson(contents), (DiskRecord[]));

            for (uint256 row; row < rows.length; ++row) {
                _storeEntry(
                    rows[row].label,
                    rows[row].location,
                    network,
                    rows[row].hasCode
                );
            }
        }
    }

    /// @notice get an address for the current chainId
    /// @param name the name of the address
    function getAddress(string memory name) public view returns (address) {
        return _lookupEntry(name, block.chainid);
    }

    /// @notice get an address for a specific chainId
    /// @param name the name of the address
    /// @param chainId the chain id
    function getAddress(string memory name, uint256 chainId)
        public
        view
        returns (address)
    {
        return _lookupEntry(name, chainId);
    }

    /// @notice add an address for the current chainId
    /// @param name the name of the address
    /// @param addr the address to add
    /// @param isContract whether the address is a contract
    function addAddress(string memory name, address addr, bool isContract)
        public
    {
        _storeEntry(name, addr, block.chainid, isContract);
        additions.push(AddedMarker({label: name, network: block.chainid}));
    }

    /// @notice add an address for a specific chainId
    /// @param name the name of the address
    /// @param addr the address to add
    /// @param chainId the chain id
    /// @param isContract whether the address is a contract
    function addAddress(
        string memory name,
        address addr,
        uint256 chainId,
        bool isContract
    ) public {
        _storeEntry(name, addr, chainId, isContract);
        additions.push(AddedMarker({label: name, network: chainId}));
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

    /// @notice change an address for a specific chainId
    /// @param name the name of the address
    /// @param addr the address to change to
    /// @param chainId the chain id
    /// @param isContract whether the address is a contract
    function changeAddress(
        string memory name,
        address addr,
        uint256 chainId,
        bool isContract
    ) public {
        RegistryRecord storage existing = registry[name][chainId];

        require(addr != address(0), "Address cannot be 0");
        require(chainId != 0, "ChainId cannot be 0");
        require(
            existing.location != address(0),
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " doesn't exist on chain: ",
                    forgeVm.toString(chainId),
                    ". Use addAddress instead"
                )
            )
        );
        require(
            existing.location != addr,
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " already set to the same value on chain: ",
                    forgeVm.toString(chainId)
                )
            )
        );

        _assertCodeMatches(addr, isContract, name, chainId);

        replacements.push(
            ReplacedMarker({
                label: name, network: chainId, priorLocation: existing.location
            })
        );

        for (uint256 cursor; cursor < persisted.length; ++cursor) {
            if (
                keccak256(abi.encode(persisted[cursor].label))
                        == keccak256(abi.encode(name))
                    && persisted[cursor].network == chainId
            ) {
                persisted[cursor].location = addr;
            }
        }

        existing.location = addr;
        existing.hasCode = isContract;
        forgeVm.label(addr, name);
    }

    /// @notice remove recorded addresses
    function resetRecordingAddresses() external {
        delete additions;
    }

    /// @notice remove changed addresses
    function resetChangedAddresses() external {
        delete replacements;
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
        uint256 count = additions.length;
        names = new string[](count);
        chainIds = new uint256[](count);
        addresses = new address[](count);

        for (uint256 cursor; cursor < count; ++cursor) {
            AddedMarker storage entry = additions[cursor];
            names[cursor] = entry.label;
            chainIds[cursor] = entry.network;
            addresses[cursor] = registry[entry.label][entry.network].location;
        }
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
        uint256 count = replacements.length;
        names = new string[](count);
        chainIds = new uint256[](count);
        oldAddresses = new address[](count);
        newAddresses = new address[](count);

        for (uint256 cursor; cursor < count; ++cursor) {
            ReplacedMarker storage entry = replacements[cursor];
            names[cursor] = entry.label;
            chainIds[cursor] = entry.network;
            oldAddresses[cursor] = entry.priorLocation;
            newAddresses[cursor] = registry[entry.label][entry.network].location;
        }
    }

    /// @notice check if an address is a contract
    /// @param name the name of the address
    function isAddressContract(string memory name) public view returns (bool) {
        return registry[name][block.chainid].hasCode;
    }

    /// @notice check if an address is set
    /// @param name the name of the address
    function isAddressSet(string memory name) public view returns (bool) {
        return registry[name][block.chainid].location != address(0);
    }

    /// @notice check if an address is set for a specific chain id
    /// @param name the name of the address
    /// @param chainId the chain id
    function isAddressSet(string memory name, uint256 chainId)
        public
        view
        returns (bool)
    {
        return registry[name][chainId].location != address(0);
    }

    /// @dev Print new recorded and changed addresses
    function printJSONChanges() external view {
        {
            (string[] memory names,, address[] memory addresses) =
                getRecordedAddresses();

            if (names.length > 0) {
                console.log(
                    "\n\n------------------ Addresses Added ------------------"
                );
                for (uint256 cursor; cursor < names.length; ++cursor) {
                    console.log(
                        "{\n          \"addr\": \"%s\", ", addresses[cursor]
                    );
                    console.log("        \"isContract\": %s,", true);
                    console.log(
                        "        \"name\": \"%s\"\n}%s",
                        names[cursor],
                        cursor < names.length - 1 ? "," : ""
                    );
                }
            }
        }

        {
            (string[] memory names,,, address[] memory addresses) =
                getChangedAddresses();

            if (names.length > 0) {
                console.log(
                    "\n\n----------------- Addresses changed  -----------------"
                );
                for (uint256 cursor; cursor < names.length; ++cursor) {
                    console.log(
                        "{\n          'addr': '%s', ", addresses[cursor]
                    );
                    console.log("        'chainId': %d,", block.chainid);
                    console.log("        'isContract': %s", true, ",");
                    console.log(
                        "        'name': '%s'\n}%s",
                        names[cursor],
                        cursor < names.length - 1 ? "," : ""
                    );
                }
            }
        }
    }

    /// @dev Update Address json
    function updateJson() external {
        for (uint256 cursor; cursor < knownNetworks.length; ++cursor) {
            uint256 network = knownNetworks[cursor];
            string memory json = _renderJson(network);
            string memory document = string(
                abi.encodePacked(
                    rootDirectory, "/", forgeVm.toString(network), ".json"
                )
            );
            forgeVm.writeJson(json, document);
        }
    }

    function _storeEntry(
        string memory name,
        address addr,
        uint256 chainId,
        bool isContract
    ) private {
        RegistryRecord storage destination = registry[name][chainId];

        require(addr != address(0), "Address cannot be 0");
        require(chainId != 0, "ChainId cannot be 0");
        require(
            destination.location == address(0),
            string(
                abi.encodePacked(
                    "Address with name: ",
                    name,
                    " already set on chain: ",
                    forgeVm.toString(chainId)
                )
            )
        );
        require(
            !reverseRegistry[addr][chainId],
            string(
                abi.encodePacked(
                    "Address: ",
                    forgeVm.toString(addr),
                    " already set on chain: ",
                    forgeVm.toString(chainId)
                )
            )
        );

        reverseRegistry[addr][chainId] = true;
        _assertCodeMatches(addr, isContract, name, chainId);

        destination.location = addr;
        destination.hasCode = isContract;
        persisted.push(
            PersistedRecord({
                label: name,
                location: addr,
                network: chainId,
                hasCode: isContract
            })
        );

        forgeVm.label(addr, name);
    }

    function _lookupEntry(string memory name, uint256 chainId)
        private
        view
        returns (address result)
    {
        require(chainId != 0, "ChainId cannot be 0");

        result = registry[name][chainId].location;
        require(
            result != address(0),
            string(
                abi.encodePacked(
                    "Address: ",
                    name,
                    " not set on chain: ",
                    forgeVm.toString(chainId)
                )
            )
        );
    }

    function _assertCodeMatches(
        address addr,
        bool isContract,
        string memory name,
        uint256 chainId
    ) private view {
        if (chainId == block.chainid) {
            if (isContract) {
                require(
                    addr.code.length > 0,
                    string(
                        abi.encodePacked(
                            "Address: ",
                            name,
                            " is not a contract on chain: ",
                            forgeVm.toString(chainId)
                        )
                    )
                );
            } else {
                require(
                    addr.code.length == 0,
                    string(
                        abi.encodePacked(
                            "Address: ",
                            name,
                            " is a contract on chain: ",
                            forgeVm.toString(chainId)
                        )
                    )
                );
            }
        }
    }

    function _renderJson(uint256 chainId) private view returns (string memory) {
        string memory json = "[";

        for (uint256 cursor; cursor < persisted.length; ++cursor) {
            PersistedRecord storage entry = persisted[cursor];
            if (entry.network == chainId) {
                json = string(
                    abi.encodePacked(
                        json,
                        "{",
                        '"addr": "',
                        forgeVm.toString(entry.location),
                        '",',
                        '"name": "',
                        entry.label,
                        '",',
                        '"isContract": ',
                        entry.hasCode ? "true" : "false",
                        "},"
                    )
                );
            }
        }

        json = _dropFinalByte(json);
        return string(abi.encodePacked(json, "]"));
    }

    function _dropFinalByte(string memory input)
        private
        pure
        returns (string memory)
    {
        bytes memory source = bytes(input);
        bytes memory shortened = new bytes(source.length - 1);

        for (uint256 cursor; cursor < shortened.length; ++cursor) {
            shortened[cursor] = source[cursor];
        }

        return string(shortened);
    }
}
