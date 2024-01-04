import {TIMELOCK_SIMULATOR } from "@examples/timelock/TIMELOCK_SIMULATOR.sol";
import {ScriptSuite} from "./ScriptSuite.s.sol";

contract TimulockSimulationScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    constructor() ScriptSuite(ADDRESSES_PATH, new TIMELOCK_SIMULATOR()) {}

	function run(uint256 proposalId) public override {
	    proposal.setDebug(true);
	    super.run(proposalId);
	}

}
