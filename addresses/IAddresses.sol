// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/// @notice This is a contract that stores addresses for different networks.
/// It allows a project to have a single source of truth to get all the addresses
/// for a given network.
interface IAddresses {
    /// @notice get an address for the current chainId
    /// @param name the name of the address
    function getAddress(string memory name) external view returns (address);

    /// @notice get an address for a specific chainId
    /// @param name the name of the address
    function getAddress(
        string memory name,
        uint256 chainId
    ) external view returns (address);

    /// @notice add an address for the current chainId
    /// @param name the name of the address
    /// @param addr the address to add
    /// @param isContract whether the address is a contract
    function addAddress(
        string memory name,
        address addr,
        bool isContract
    ) external;

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
    ) external;

    /// @notice change an address for the current chainId
    /// @param name the name of the address
    /// @param addr the address to change
    /// @param isContract whether the address is a contract
    function changeAddress(
        string memory name,
        address addr,
        bool isContract
    ) external;

    /// @notice change an address for a specific chainId
    /// @param name the name of the address
    /// @param addr the address to change
    /// @param chainId the chain id
    /// @param isContract whether the address is a contract
    function changeAddress(
        string memory name,
        address addr,
        uint256 chainId,
        bool isContract
    ) external;

    /// @notice remove recorded addresses
    function resetRecordingAddresses() external;

    /// @notice remove changed addresses
    function resetChangedAddresses() external;

    /// @notice get recorded addresses from a proposal's deployment
    function getRecordedAddresses()
        external
        view
        returns (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory addresses
        );

    /// @notice get changed addresses from a proposal
    function getChangedAddresses()
        external
        view
        returns (
            string[] memory names,
            uint256[] memory chainIds,
            address[] memory oldAddresses,
            address[] memory newAddresses
        );

    /// @notice check if an address is a contract
    /// @param name the name of the address
    function isAddressContract(string memory name) external view returns (bool);

    /// @notice check if an address is set
    /// @param name the name of the address
    function isAddressSet(string memory name) external view returns (bool);

    /// @notice check if an address is set for a specific chain id
    /// @param name the name of the address
    /// @param chainId the chain id
    function isAddressSet(
        string memory name,
        uint256 chainId
    ) external view returns (bool);
}
