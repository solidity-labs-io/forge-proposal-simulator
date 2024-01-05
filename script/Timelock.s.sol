pragma solidity 0.8.19;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";
import {TimelockController} from "@openzeppelin/governance/TimelockController.sol";
import {TIMELOCK_01} from "@examples/timelock/TIMELOCK_01.sol";
import {Constants} from "@utils/Constants.sol";

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
