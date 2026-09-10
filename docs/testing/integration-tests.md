# Integration Tests

Run a proposal from `setUp()` when an integration test needs the state produced by that proposal. The setup contract deploys the latest compiled proposal artifact, keeps the proposal contract available when it selects a fork, runs the proposal, and exposes its `Addresses` registry to the test.

The complete multisig implementation is in the [`fps-example-repo` test directory](https://github.com/solidity-labs-io/fps-example-repo/tree/main/test/multisig).

## Configure Foundry

The proposal initializes its own fork in its `run()` override. Define the RPC alias used by the proposal and allow reads from the repository so `Addresses` can load its per-chain JSON files:

```toml
[profile.default]
fs_permissions = [{ access = "read", path = "./" }]

[rpc_endpoints]
sepolia = "${SEPOLIA_RPC_URL}"
```

The test uses the `ffi` cheatcode to run a local artifact-selection script. FFI executes host commands and is disabled by default. Enable it only for commands committed to and reviewed with the repository.

## Find the Latest Proposal Artifact

Create `get-latest-proposal.sh` at the repository root:

```bash
#!/usr/bin/env bash
set -euo pipefail

base_dir="out"
proposal_type="${1:?proposal type is required}"
latest_number=-1
latest_directory=""

shopt -s nullglob
for directory in "$base_dir"/"${proposal_type}"_*.sol; do
    filename="${directory##*/}"
    suffix="${filename#"${proposal_type}"_}"
    number="${suffix%.sol}"

    [[ "$number" =~ ^[0-9]+$ ]] || continue
    numeric_value=$((10#$number))

    if ((numeric_value > latest_number)); then
        latest_number=$numeric_value
        latest_directory="$directory"
    fi
done

if [[ -z "$latest_directory" ]]; then
    echo "No ${proposal_type}_<number>.sol artifact found in ${base_dir}" >&2
    exit 1
fi

contract_name="${latest_directory##*/}"
contract_name="${contract_name%.sol}"
printf '%s/%s.json\n' "$latest_directory" "$contract_name"
```

Make the script executable:

```bash
chmod +x get-latest-proposal.sh
```

For `MultisigProposal_02.sol`, the script returns `out/MultisigProposal_02.sol/MultisigProposal_02.json`. `deployCode()` reads that artifact and deploys its creation bytecode.

## Execute the Proposal in `setUp()`

Create `test/multisig/MultisigPostProposalCheck.sol`:

```solidity
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@forge-proposal-simulator/addresses/Addresses.sol";
import {MultisigProposal} from "@forge-proposal-simulator/src/proposals/MultisigProposal.sol";

contract MultisigPostProposalCheck is Test {
    Addresses public addresses;

    function setUp() public virtual {
        string[] memory inputs = new string[](2);
        inputs[0] = "./get-latest-proposal.sh";
        inputs[1] = "MultisigProposal";

        string memory artifact = string(vm.ffi(inputs));
        MultisigProposal proposal = MultisigProposal(deployCode(artifact));

        vm.makePersistent(address(proposal));
        proposal.run();

        addresses = proposal.addresses();
    }
}
```

The proposal is deployed before its `run()` override selects a fork. `vm.makePersistent()` keeps the proposal contract available after that fork change. The override must configure `primaryForkId`, `addresses`, and any governance-specific contracts before it calls `super.run()`.

`proposal.run()` executes the enabled lifecycle stages in order: `deploy()`, `preBuildMock()`, `build()`, `simulate()`, `validate()`, and `print()`, followed by optional address JSON persistence. The defaults execute every stage except JSON persistence. The integration test therefore starts from the state left by `simulate()` and checked by `validate()`.

## Write Integration Tests

Inherit the setup contract and read deployed or changed addresses from its registry:

```solidity
pragma solidity ^0.8.0;

import {Token} from "src/mocks/vault/Token.sol";
import {Vault} from "src/mocks/vault/Vault.sol";
import {MultisigPostProposalCheck} from "./MultisigPostProposalCheck.sol";

contract MultisigVaultIntegrationTestSepolia is MultisigPostProposalCheck {
    function test_addTokenToWhitelist() public {
        Vault vault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        address multisig = addresses.getAddress("DEV_MULTISIG");
        Token token = new Token();

        vm.prank(multisig);
        vault.whitelistToken(address(token), true);

        assertTrue(vault.tokenWhitelist(address(token)));
    }

    function test_depositToVault() public {
        Vault vault = Vault(addresses.getAddress("MULTISIG_VAULT"));
        address multisig = addresses.getAddress("DEV_MULTISIG");
        Token token = Token(addresses.getAddress("MULTISIG_TOKEN"));

        (uint256 previousDeposits,) =
            vault.deposits(address(token), multisig);
        uint256 depositAmount = 100;

        vm.startPrank(multisig);
        token.mint(multisig, depositAmount);
        token.approve(address(vault), depositAmount);
        vault.deposit(address(token), depositAmount);
        vm.stopPrank();

        (uint256 deposits,) = vault.deposits(address(token), multisig);
        assertEq(deposits, previousDeposits + depositAmount);
    }
}
```

## Run the Tests

Run the command from the repository root. Forge compiles the proposals before the test invokes the artifact-selection script.

```bash
forge test \
  --match-contract MultisigVaultIntegrationTestSepolia \
  --ffi \
  -vvv
```

Forge creates a fresh test state and calls `setUp()` before each test. Each case receives a fresh proposal execution on a fresh fork.
