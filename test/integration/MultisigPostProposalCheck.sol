pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import {TestSuite} from "@test/TestSuite.t.sol";
import {MULTISIG_01} from "@examples/multisig/MULTISIG_01.sol";
import {MULTISIG_02} from "@examples/multisig/MULTISIG_02.sol";
import {MULTISIG_03} from "@examples/multisig/MULTISIG_03.sol";
import {Vault} from "@examples/Vault.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Constants} from "@utils/Constants.sol";
import {MockToken} from "@examples/MockToken.sol";

contract MultisigPostProposalCheck is Test {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    TestSuite public suite;

    function setUp() virtual {
        MULTISIG_01 multisigProposal = new MULTISIG_01();
        MULTISIG_02 multisigProposal2 = new MULTISIG_02();
        MULTISIG_03 multisigProposal3 = new MULTISIG_03();

        address[] memory proposalsAddresses = new address[](3);
        proposalsAddresses[0] = address(multisigProposal);
        proposalsAddresses[1] = address(multisigProposal2);
        proposalsAddresses[2] = address(multisigProposal3);
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);

        // Verify if the multisig address is a contract; if is not (e.g. running on a empty blockchain node), etch Gnosis Safe bytecode onto it.
        addresses = suite.addresses();
        address multisig = addresses.getAddress("DEV_MULTISIG");
        uint256 multisigSize;
        assembly {
            multisigSize := extcodesize(multisig)
        }
        if (multisigSize == 0) {
            vm.etch(multisig, Constants.SAFE_BYTECODE);
        }

        suite.setDebug(true);
        suite.testProposals();
    }

}
