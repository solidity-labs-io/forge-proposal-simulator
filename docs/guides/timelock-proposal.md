# Timelock Proposal

After adding FPS into project dependencies, the next step involves initiating
the creation of the first Proposal contract. This example provides guidance on
formulating a proposal for deploying new instances of `Vault.sol` and
`MockToken`. These contracts are located in the [guides
section](./introduction.md#example-contracts). The proposal includes the transfer of
ownership of both contracts to the timelock controller, along with the whitelisting of the token and minting of tokens to the timelock.

In the `proposals` folder, create a new file called `TIMELOCK_01.sol` and add the following code:

```solidity
pragma solidity ^0.8.0;

import { TimelockProposal } from "@forge-proposal-simulator/proposals/TimelockProposal.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { Vault } from "path/to/Vault.sol";
import { MockToken } from "path/to/MockToken.sol";

// TIMELOCK_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the timelock address
// Finally the proposal whitelist the ERC20 token in the Vault contract
contract TIMELOCK_01 is TimelockProposal {
    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "TIMELOCK_01";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Timelock proposal mock";
    }

    // Deploys a vault contract and an ERC20 token contract.
    function _deploy(Addresses addresses, address) internal override {
        // Deploy needed contracts
        Vault timelockVault = new Vault();
        MockToken token = new MockToken();

        // Add deployed contracts to the address registry
        addresses.addAddress("VAULT", address(timelockVault), true);
        addresses.addAddress("TOKEN_1", address(token), true);
    }

    // Transfers vault ownership to timelock.
    // Transfer token ownership to timelock.
    // Transfers all tokens to timelock.
    function _afterDeploy(
        Addresses addresses,
        address deployer
    ) internal override {
        // Get needed addresses from addresses registry
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        // Transfer ownership of the contracts to the multisig address
        timelockVault.transferOwnership(timelock);
        token.transferOwnership(timelock);

        // Transfer tokens from deployer to multisig address
        token.transfer(timelock, token.balanceOf(address(deployer)));
    }

    // Sets up actions for the proposal, in this case, setting the MockToken to active.
    function _build(Addresses addresses) internal override {
        // Get vault and token addresses (deployed on _deploy step)
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");

        // Push action to whitelist the MockToken
        _pushAction(
            timelockVault,
            abi.encodeWithSignature(
                "whitelistToken(address,bool)",
                token,
                true
            ),
            "Set token to active"
        );
    }

    // Executes the proposal actions.
    function _run(Addresses addresses, address) internal override {
        // Call parent _run function to check if there are actions to execute
        super._run(addresses, address(0));

        // Get needed addresses from addresses registry
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
        address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

        // Simulates actions on TimelockController
        _simulateActions(timelock, proposer, executor);
    }

    // Validates the post-execution state.
    function _validate(Addresses addresses, address) internal override {
        // Get needed addresses from addresses registry
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        // Validate post-execution state
        // Vault ownership should be transferred to timelock
        assertEq(timelockVault.owner(), timelock);
        // Token should be whitelisted on the Vault contract
        assertTrue(timelockVault.tokenWhitelist(address(token)));
        // Vault should not be paused
        assertFalse(timelockVault.paused());
        // Token ownership should be transferred to timelock
        assertEq(token.owner(), timelock);
        // Token balance of multisig should be equal to total supply
        assertEq(token.balanceOf(timelock), token.totalSupply());
    }
}
```

Let's go through each of the functions we are overriding here.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `_deploy()`: Deploy any necessary contracts. This example demonstrates the
    deployment of Vault and an ERC20 token. Once the contracts are deployed,
    they are added to the `Addresses` contract by calling `addAddress()`.
-   `_build(`): Set the necessary actions for your proposal. In this example, ERC20 token is whitelisted on the Vault contract
-   `_run()`: Execute the proposal actions outlined in the `_build()` step. This
    function performs a call to `_simulateActions` from the inherited
    `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [excheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.
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
        "addr": "0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f",
        "name": "TIMELOCK_PROPOSER",
        "chainId": 31337
    },
    {
        "addr": "0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f",
        "name": "TIMELOCK_EXECUTOR",
        "chainId": 31337
    }
]
```

With the JSON file prepared for use with `Addresses.sol`, the next step is to create a script that inherits from `ScriptSuite`. Create file `TimelockScript.s.sol` in the `scripts` folder and add the following code:

```solidity
pragma solidity ^0.8.0;

import { ScriptSuite } from "@forge-proposal-simulator/script/ScriptSuite.s.sol";
import { TimelockController } from "@openzeppelin/governance/TimelockController.sol";
import { TIMELOCK_01 } from "proposals/TIMELOCK_01.sol";

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

    function run() public override {
        // Verify if the timelock address is a contract; if is not (e.g. running on a empty blockchain node), deploy a new TimelockController and update the address.
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        uint256 timelockSize;
        assembly {
            // retrieve the size of the code, this needs assembly
            timelockSize := extcodesize(timelock)
        }
        if (timelockSize == 0) {
            // Get proposer and executor addresses
            address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
            address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

            // Create arrays of addresses to pass to the TimelockController constructor
            address[] memory proposers = new address[](1);
            proposers[0] = proposer;
            address[] memory executors = new address[](1);
            executors[0] = executor;

            // Deploy a new TimelockController
            TimelockController timelockController = new TimelockController(
                10_000,
                proposers,
                executors,
                address(0)
            );
            // Update PROTOCOL_TIMELOCK address
            addresses.changeAddress(
                "PROTOCOL_TIMELOCK",
                address(timelockController)
            );

            proposal.setDebug(true);

            // Execute proposal
            super.run();
        }
    }
}
```

Running the script:

```sh
forge script script/TimelockScript.s.sol
```

The script will output the following:

```sh
== Logs ==
Proposal Description:

Timelock proposal mock


------------------ Proposal Actions ------------------
  1). Set token to active
  target: 0x90193C961A926261B756D1E5bb255e67ff9498A1
payload
  0x0ffb1d8b000000000000000000000000a8452ec99ce0c64f20701db7dd3abdb607c004960000000000000000000000000000000000000000000000000000000000000001


  Calldata for scheduleBatch:
  0x8f2a0bb000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000000238c9fb6d28e3dd9c74cc712adacdd43b8bda99137a1dc4751a7d6671fa25fda0000000000000000000000000000000000000000000000000000000000002710000000000000000000000000000000000000000000000000000000000000000100000000000000000000000090193c961a926261b756d1e5bb255e67ff9498a1000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000a8452ec99ce0c64f20701db7dd3abdb607c00496000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000


Proposal Description:

Timelock proposal mock


------------------ Proposal Actions ------------------
  1). Set token to active
  target: 0x90193C961A926261B756D1E5bb255e67ff9498A1
payload
  0x0ffb1d8b000000000000000000000000a8452ec99ce0c64f20701db7dd3abdb607c004960000000000000000000000000000000000000000000000000000000000000001


  Calldata for executeBatch:
  0xe38335e500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000000238c9fb6d28e3dd9c74cc712adacdd43b8bda99137a1dc4751a7d6671fa25fda000000000000000000000000000000000000000000000000000000000000000100000000000000000000000090193c961a926261b756d1e5bb255e67ff9498a1000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000a8452ec99ce0c64f20701db7dd3abdb607c00496000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000


Proposal Description:

Timelock proposal mock


------------------ Proposal Actions ------------------
  1). Set token to active
  target: 0x90193C961A926261B756D1E5bb255e67ff9498A1
payload
  0x0ffb1d8b000000000000000000000000a8452ec99ce0c64f20701db7dd3abdb607c004960000000000000000000000000000000000000000000000000000000000000001


  schedule batch calldata with  1 action
  executed batch calldata
  Addresses added after running proposals:
  VAULT 0x90193C961A926261B756D1E5bb255e67ff9498A1
  TOKEN_1 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
```

As the Timelock executor, you have the ability to run the script to execute the proposal. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.
