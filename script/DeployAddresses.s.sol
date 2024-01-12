pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Addresses} from "@addresses/Addresses.sol";

contract DeployAddresses is Script {
    Addresses addresses;

    function run() public virtual {
        string memory addressesPath = "./addresses/Addresses.json";
        addresses = new Addresses(addressesPath);
    }
}
