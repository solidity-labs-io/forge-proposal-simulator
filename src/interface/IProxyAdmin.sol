// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IProxyAdmin {
    function upgrade(address proxy, address implementation) external;
}
