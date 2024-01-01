pragma solidity 0.8.19;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";
import {MULTISIG_01} from "@examples/multisig/MULTISIG_01.sol";

contract MultisigScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    
    constructor() ScriptSuite(ADDRESSES_PATH, new MULTISIG_01()) {}
     
     function run() public override  {
        proposal.setDebug(true);
        super.run();
    }
}
