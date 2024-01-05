pragma solidity 0.8.19;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
import {TIMELOCK_01} from "@examples/timelock/TIMELOCK_01.sol";
import {Constants} from "@utils/Constants.sol";

// @notice TimelockScript is a script that run TIMELOCK_01 proposal
// TIMELOCK_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the timelock address
// Finally the proposal whitelist the ERC20 token in the Vault contract
// @dev Use this script to simulates or run a single proposal
// Use this as a template to create your own script
// `forge script script/Timelock.s.sol:TimelockScript -vvvv --rpc-url {rpc} --broadcast --verify --etherscan-api-key {key}`
contract TimelockScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    
    constructor() ScriptSuite(ADDRESSES_PATH, new TIMELOCK_01()) {}
     
     function run() public override  {
        // Verify if the timelock address is a contract; if is not (e.g. running on a empty blockchain node), deploy a new TimelockController and update the address.
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        uint256 timelockSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
        }
        if (timelockSize == 0) {
            address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
            address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

            address[] memory proposers = new address[](1);
            proposers[0] = proposer;
            address[] memory executors = new address[](1);
            executors[0] = executor;

            TimelockController timelockController = new TimelockController(10_000, proposers, executors, address(0));
	    addresses.changeAddress("PROTOCOL_TIMELOCK", address(timelockController));
	    proposal.setDebug(true);
	    super.run();
    }
     }
}
