pragma solidity 0.8.19;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";
import {MULTISIG_01} from "@examples/multisig/MULTISIG_01.sol";
import {Constants} from "@utils/Constants.sol";

contract MultisigScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    
    constructor() ScriptSuite(ADDRESSES_PATH, new MULTISIG_01()) {}
     
     function run() public override  {
	address multisig = addresses.getAddress("DEV_MULTISIG");

        uint256 multisigSize;
        assembly {
            multisigSize := extcodesize(multisig)
        }
        if (multisigSize == 0) {
            vm.etch(multisig, Constants.SAFE_BYTECODE);
        }

        proposal.setDebug(true);
        super.run();
    }
}
