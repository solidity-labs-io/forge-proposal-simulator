# Governor Bravo Proposal

After adding FPS into project dependencies, the next step involves initiating the creation of the first Proposal contract. This example provides guidance on formulating a proposal for deploying new instances of `Vault.sol` and `MockToken`. These contracts are located in the [guides section](./introduction.md#example-contracts). The proposal includes the transfer of ownership of both contracts to Governor Bravo's timelock, along with the whitelisting of the token and minting of tokens to the timelock.

In the `proposals` folder, create a new file called `BRAVO_01.sol` and add the following code:

```solidity
pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {GovernorBravoProposal} from "@proposals/GovernorBravoProposal.sol";

/// BRAVO_01 proposal deploys a Vault contract and an ERC20 token contract
/// Then the proposal transfers ownership of both Vault and ERC20 to the governor address
/// Finally the proposal whitelist the ERC20 token in the Vault contract
contract BRAVO_01 is GovernorBravoProposal {
    /// @notice Returns the name of the proposal.
    string public override name = "BRAVO_01";

    /// @notice Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Governor Bravo proposal mock";
    }

    /// @notice Deploys a vault contract and an ERC20 token contract.
    /// @param addresses The addresses contract.
    function _deploy(Addresses addresses, address) internal override {
        if (!addresses.isAddressSet("VAULT")) {
            Vault timelockVault = new Vault();
            addresses.addAddress("VAULT", address(timelockVault), true);
        }

        if (!addresses.isAddressSet("TOKEN_1")) {
            MockToken token = new MockToken();
            addresses.addAddress("TOKEN_1", address(token), true);
        }
    }

    /// @notice steps:
    /// 1. Transfers vault ownership to timelock.
    /// 2. Transfer token ownership to timelock.
    /// 3. Transfers all tokens to timelock.
    /// @param addresses The addresses contract.
    /// @param deployer The contract deployer address.
    function _afterDeploy(
        Addresses addresses,
        address deployer
    ) internal override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(timelock);
        token.transferOwnership(timelock);
        token.transfer(timelock, token.balanceOf(address(deployer)));
    }

    /// @notice Sets up actions for the proposal, in this case, setting the MockToken to active.
    /// @param addresses The addresses contract.
    function _build(
        Addresses addresses
    )
        internal
        override
        buildModifier(addresses.getAddress("PROTOCOL_TIMELOCK"), addresses)
    {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        /// CALL -- mutative and recorded
        Vault(timelockVault).whitelistToken(token, true);
    }

    /// @notice Executes the proposal actions.
    /// @param addresses The addresses contract.
    function _run(Addresses addresses, address) internal override {
        // Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        address governor = addresses.getAddress("PROTOCOL_GOVERNOR");
        address govToken = addresses.getAddress("PROTOCOL_GOVERNANCE_TOKEN");
        address proposer = addresses.getAddress("BRAVO_PROPOSER");

        _simulateActions(governor, govToken, proposer);
    }

    /// @notice Validates the post-execution state.
    /// @param addresses The addresses contract.
    function _validate(Addresses addresses, address) internal override {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        assertEq(timelockVault.owner(), timelock);
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        assertFalse(timelockVault.paused());

        assertEq(token.owner(), timelock);
        assertEq(token.balanceOf(timelock), token.totalSupply());
    }
}
```

Let's go through each of the functions that are overridden.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `_deploy()`: Deploy any necessary contracts. This example demonstrates the
    deployment of Vault and an ERC20 token. Once the contracts are deployed,
    they are added to the `Addresses` contract by calling `addAddress()`.
-   `_build()`: Set the necessary actions for your proposal. In this example, ERC20 token is whitelisted on the Vault contract. Use the `buildModifier` to ensure that the proposal is only executed by the timelock, which is owned by the governor. If the modifier is not used, actions will not be added to the proposal array and the calldata will be generated incorrectly.
-   `_run()`: Execute the proposal actions outlined in the `_build()` step. This
    function performs a call to `_simulateActions` from the inherited
    `GovernorBravoProposal` contract. Internally, `_simulateActions()` uses the calldata generated from the actions set up in the build step, and simulates the end-to-end workflow of a successful proposal submission, starting with a call to [propose](https://github.com/compound-finance/compound-governance/blob/5e581ef817464fdb71c4c7ef6bde4c552302d160/contracts/GovernorBravoDelegate.sol#L118).
-   `_validate()`: This final step is crucial for validating the post-execution state. It ensures that the timelock is the new owner of Vault and token, the tokens were transferred to timelock and the token was whitelisted on the Vault contract

With the first proposal contract prepared, it's time to proceed with execution. There are two options available:

1. **Using `foundry test`**: Details on this method can be found in the [integration-tests.md](../testing/integration-tests.md "mention") section.
2. **Using `foundry script`**: This is the chosen method for this scenario.

Before proceeding with the `foundry script`, it is necessary to set up the
[Addresses](../overview/architecture/addresses.md) contract. The next step
involves creating an `addresses.json` file.

```json
[
    {
        "addr": "0x1a9C8182C09F50C8318d769245beA52c32BE35BC",
        "name": "PROTOCOL_TIMELOCK",
        "chainId": 31337
    },
    {
        "addr": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "name": "PROTOCOL_GOVERNOR",
        "chainId": 31337
    },
    {
        "addr": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        "name": "PROTOCOL_GOVERNANCE_TOKEN",
        "chainId": 31337
    },
    {
        "addr": "0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f",
        "name": "BRAVO_PROPOSER",
        "chainId": 31337
    }
]
```

With the JSON file prepared for use with `Addresses.sol`, the next step is to create a script that inherits from `ScriptSuite`. Create file `GovernorBravoScript.s.sol` in the `scripts/` folder and add the following code:

```solidity
pragma solidity ^0.8.0;

import {ScriptSuite} from "@script/ScriptSuite.s.sol";
import {BRAVO_01} from "@examples/governor-bravo/BRAVO_01.sol";
import {Constants} from "@utils/Constants.sol";

// @notice GovernorBravoScript is a script that runs BRAVO_01 proposal.
// BRAVO_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the timelock address
// Finally the proposal whitelist the ERC20 token in the Vault contract
// @dev Use this script to simulates or run a single proposal
// Use this as a template to create your own script
// `forge script script/GovernorBravo.s.sol:GovernorBravoScript -vvvv --rpc-url {rpc} --broadcast --verify --etherscan-api-key {key}`
contract GovernorBravoScript is ScriptSuite {
    string public constant ADDRESSES_PATH = "./addresses/Addresses.json";

    constructor() ScriptSuite(ADDRESSES_PATH, new BRAVO_01()) {}

    function run() public override {
        // Execute proposal
        proposal.setDebug(true);
        super.run();
    }
}
```

Running the script:

```sh
forge script script/GovernorBravoScript.s.sol
```

The script will output the following:

```sh
== Logs ==
Proposal Description:

Governor Bravo proposal mock


------------------ Proposal Actions ------------------
  1). Set token to active
  target: 0xDD4c722d1614128933d6DC7EFA50A6913e804E12
payload
  0x0ffb1d8b0000000000000000000000007ff9c67c93d9f7318219faacb5c619a773afef6a0000000000000000000000000000000000000000000000000000000000000001


  Calldata for proposal:
  0xda95691a00000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000dd4c722d1614128933d6dc7efa50a6913e804e12000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440ffb1d8b0000000000000000000000007ff9c67c93d9f7318219faacb5c619a773afef6a000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c476f7665726e6f7220427261766f2070726f706f73616c206d6f636b00000000
```

As the Timelock executor, you have the ability to run the script to execute the proposal. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.
