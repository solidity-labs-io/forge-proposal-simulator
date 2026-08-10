// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProxy {
    function admin() external view returns (address);

    function implementation() external view returns (address);
}
