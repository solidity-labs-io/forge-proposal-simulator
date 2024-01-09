# Timelock Proposal

After adding FPS to your project dependencies, the next step is to create your
first Proposal contract. In this example, we will create a proposal that deploys a new instance of `Vault.sol` and a new ERC20 token, then transfer ownership of both contracts to the timelock contract.

```solidity
pragma solidity 0.8.19;

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { Pausable } from "@openzeppelin/security/Pausable.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract Vault is Ownable, Pausable {
    uint256 public LOCK_PERIOD = 1 weeks;

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => mapping(address => Deposit)) public deposits;
    mapping(address => bool) public tokenWhitelist;

    constructor() Ownable() Pausable() {}

    function whitelistToken(address token, bool active) external onlyOwner {
        tokenWhitelist[token] = active;
    }

    function deposit(address token, uint256 amount) external whenNotPaused {
        require(tokenWhitelist[token], "Vault: token must be active");
        require(amount > 0, "Vault: amount must be greater than 0");
        require(token != address(0), "Vault: token must not be 0x0");

        Deposit storage userDeposit = deposits[token][msg.sender];
        userDeposit.amount += amount;
        userDeposit.timestamp = block.timestamp;

        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(
        address token,
        address payable to,
        uint256 amount
    ) external whenNotPaused {
        require(tokenWhitelist[token], "Vault: token must be active");
        require(amount > 0, "Vault: amount must be greater than 0");
        require(token != address(0), "Vault: token must not be 0x0");
        require(
            deposits[token][msg.sender].amount >= amount,
            "Vault: insufficient balance"
        );
        require(
            deposits[token][msg.sender].timestamp + LOCK_PERIOD <
                block.timestamp,
            "Vault: lock period has not passed"
        );

        Deposit storage userDeposit = deposits[token][msg.sender];
        userDeposit.amount -= amount;

        IERC20(token).transfer(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
```

```solidity
pragma solidity 0.8.19;

import { TImelockProposal } from "@forge-proposal-simulator/proposals/MultisigProposal.sol";
import { Addresses } from "@forge-proposal-simulator/addresses/Addresses.sol";
import { Vault } from "@path/to/Vault.sol";
import { MockToken } from "@path/to/MockToken.sol";

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
        Vault timelockVault = new Vault();
        MockToken token = new MockToken();

        addresses.addAddress("VAULT", address(timelockVault));
        addresses.addAddress("TOKEN_1", address(token));
    }

    // Transfers vault ownership to timelock.
    // Transfer token ownership to timelock.
    // Transfers all tokens to timelock.
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

    // Sets up actions for the proposal, in this case, setting the MockToken to active.
    function _build(Addresses addresses) internal override {
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
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
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        address proposer = addresses.getAddress("TIMELOCK_PROPOSER");
        address executor = addresses.getAddress("TIMELOCK_EXECUTOR");

        _simulateActions(timelock, proposer, executor);
    }

    // Validates the post-execution state.
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

Let's go through each of the functions we are overriding here.

-   `name()`: Define the name of your proposal.
-   `description()`: Provide a detailed description of your proposal.
-   `_deploy()`: Deploy any necessary contracts. This example demonstrates the deployment of Vault and an ERC20 token.
-   `_build(`): Set the necessary actions for your proposal. In this example, ERC20 token is whitelisted on the Vault contract
-   `_run()`: Execute the proposal actions outlined in the `_build()` step. This
    function performs a call to `_simulateActions` from the inherited
    `TimelockProposal` contract. Internally, `_simulateActions()` simulates a call to Timelock [excheduleBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L291) and [executeBatch](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/governance/TimelockController.sol#L385) with the calldata generated from the actions set up in the build step.
-   `_validate(`): This final step is crucial for validating the post-execution state. It ensures that the timelock is the new owner of Vault and token, the tokens were transferred to timelock and the token was whitelisted on the Vault contract

Now that your first proposal contract is ready, it's time to take action. You have two options to execute the contract. The first option is to use `foundry test`. You can learn how to do that on [integration-tests.md](../testing/integration-tests.md "mention") section. The second option is to use `foundry script`, which is the method we will use here. But first, we need to set up [Addresses](../overview/architecture/addresses.md) contract. Let's create a `Addresses.json` file:

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

Now that we have the JSON file to be used on `Addresses.sol`, let's create a script that inherits `ScriptSuite`.

```solidity
import { ScriptSuite } from "@forge-proposal-simulator/script/ScriptSuite.s.sol";
import { TIMELOCK_01 } from "@path/to/TIMELOCK_01.sol";

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
forge script path/to/TimelockScript.s.sol
```

You will see an output like this:

```sh
== Logs ==
  Addresses before running proposal:
  DEV_MULTISIG 0x3dd46846eed8D147841AE162C8425c08BD8E1b41
  TEAM_MULTISIG 0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9
  PROTOCOL_TIMELOCK 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
  DAO_MULTISIG 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f
  TIMELOCK_PROPOSER 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f
  TIMELOCK_EXECUTOR 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f
  salt:
  0x238c9fb6d28e3dd9c74cc712adacdd43b8bda99137a1dc4751a7d6671fa25fda


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
  Addresses after running proposals:
  DEV_MULTISIG 0x3dd46846eed8D147841AE162C8425c08BD8E1b41
  TEAM_MULTISIG 0x7da82C7AB4771ff031b66538D2fB9b0B047f6CF9
  PROTOCOL_TIMELOCK 0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
  DAO_MULTISIG 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f
  TIMELOCK_PROPOSER 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f
  TIMELOCK_EXECUTOR 0x10A19e7eE7d7F8a52822f6817de8ea18204F2e4f
  VAULT 0x90193C961A926261B756D1E5bb255e67ff9498A1
  TOKEN_1 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
```

If you are the Timelock executor, you can run the script to execute the proposal. Please note that two new addresses have been added to `Addresses` storage but are not included in the JSON file. You will need to add them manually to the JSON.
