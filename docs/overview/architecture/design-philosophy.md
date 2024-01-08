# Design Philosophy

FPS is designed to be used in the following way:&#x20;

### Proposal file

Creates a `PROPOSAL_N.sol` (you can use any desired file name specification) file, which must inherit one of the Proposals models from FPS (e.g. `TimelockProposal.sol`)  &#x20;

```solidity
import {TimelockProposal} from "@forge-proposal-simulator/proposals/TimelockProposal.sol"

contract PROPOSAL_01 is TimelockProposal {
// check documentation for External and Internal functions 
// to determine which ones to override
}
```

### Tests

Uses `PROPOSAL_N.sol` in test suites based on your protocol architecture. You can use the pre-defined test suites from FPS

```solidity
import {TestSuite} from "@forge-proposal-simulator/test/TestSuite.t.sol"
import {PROPOSAL_01} from "./governance/proposals/PROPOSAL_01.sol"
  
contract ProposalIntegrationTest {
    string public constant ADDRESSES_PATH = "./governance/Addresses.json";
    TestSuite public suite;

    function setUp() public {
        PROPOSAL_01 proposal = new PROPOSAL_01();

        address[] memory proposalsAddresses = new address[](1);
        proposalsAddresses[0] = address(proposal);
        suite = new TestSuite(ADDRESSES_PATH, proposalsAddresses);
    }

    function test_runPoposals() public virtual {
        preProposalsSnapshot = vm.snapshot();

        suite.setDebug(true);
        suite.testProposals();

        postProposalsSnapshot = vm.snapshot();
    }

}
```

### Scripts

Uses `PROPOSAL_N.sol` in scripts based on your protocol architecture. You can use the pre-defined script suites from FPS

```solidity
import {ScriptSuite} from "@forge-proposal-simulator/script/ScriptSuite.s.sol"
import {PROPOSAL_01} from "./governance/proposals/PROPOSAL_01.sol"

contract ProposalScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";
    
    constructor() ScriptSuite(ADDRESSES_PATH, new PROPOSAL_01()) {}
     
     function run() public override  {
        proposal.setDebug(true);
        super.run();
    }
}

```

Then run the script:

```sh
forge script path/to/script/ProposalScript.s.sol:ProposalScript 
```
