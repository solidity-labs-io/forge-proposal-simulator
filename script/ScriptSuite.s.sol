pragma solidity 0.8.19;

import "forge-std/Script.sol";

contract ScriptSuite is Script {
    IProposal proposal;
    Addresses addresses;

    constructor(string memory ADDRESS_PATH, address proposal) {
        addresses = new Addresses(ADDRESS_PATH);
        proposal = IProposal(proposal);
    }

    function run() external virtual {
        uint256 signerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        proposal.run(addresses, msg.sender);
        vm.stopBroadcast();
    }
}
