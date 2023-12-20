pragma solidity 0.8.19;

import {Test} from "@forge-std/Test.sol";
import {IProposal} from "@proposals/proposalTypes/IProposal.sol";
import {Script} from "@forge-std/Script.sol";
import {Addresses} from "@addresses/Addresses.sol";

abstract contract Proposal is Test, Script, IProposal {
    struct Action {
        address target;
        uint256 value;
        bytes arguments;
        string description;
    }

    Action[] public actions;

    bool internal DEBUG;

    // @notice override this to set the proposal name
    function name() external view virtual returns (string memory) {}

    // @notice the main function, should not be override
    function run(Addresses addresses, address deployer) external {
        vm.startBroadcast(deployer);
        _deploy(addresses, deployer);
        _afterDeploy(addresses, deployer);
        _afterDeploySetup(addresses);
        vm.stopBroadcast();

	_build(addresses);
	_run(addresses, deployer);
	_teardown(addresses, deployer);
	_validate(addresses, deployer);
    }

    // @notice the main function, should not be override
    function run(Addresses addresses, address deployer,
		 bool doDeploy,
		 bool doAfterDeploy,
		 bool doBuild,
		 bool doRun,
		 bool doTeardown,
		 bool doValidate) external {

	vm.startBroadcast(deployer);

	if(doDeploy) {
	    _deploy(addresses, deployer);
	}

	if(doAfterDeploy) {
        _afterDeploy(addresses, deployer);
	}

        vm.stopBroadcast();

	if(doBuild) {
	    _build(addresses);
	}
	if(doRun) {
	    _run(addresses, deployer);
	}
	if(doTeardown) {
	    _teardown(addresses, deployer);
	}
	if(doValidate) {
	    _validate(addresses, deployer);
	}
    }

    // @dev set the debug flag
    function setDebug(bool debug) public {
        DEBUG = debug;
    }

    // @notice Print out proposal steps one by one
    // print proposal description
    function printProposalActionSteps() public virtual {}

    // @notice Print proposal calldata
    function printCalldata() public virtual returns(bytes memory data){}

    // @dev push an action to the proposal
    function _pushAction(uint256 value, address target, bytes memory data, string memory description) internal {
        actions.push(Action({value: value, target: target, arguments: data, description: description}));
    }

    // @dev push an action to the proposal with a value of 0
    function _pushAction(address target, bytes memory data, string memory description) internal {
        _pushAction(0, target, data, description);
    }

    // @dev push an action to the proposal with empty description
    function _pushAction(uint256 value, address target, bytes memory data) internal {
        _pushAction(value, target, data, "");
    }

    // @dev push an action to the proposal with a value of 0 and empty description
    function _pushAction(address target, bytes memory data) internal {
        _pushAction(0, target, data, "");
    }

    // @dev Deploy contracts and add them to list of addresses
    function _deploy(Addresses, address) internal virtual {}

    // @dev After deploying, call initializers and link contracts together
    function _afterDeploy(Addresses, address) internal virtual {}

    // @dev After deploying, do setup for a testnet,
    // e.g. if you deployed a contract that needs funds
    // for a governance proposal, deal them funds
    function _afterDeploySetup(Addresses) internal virtual {}

    /// @dev After finishing deploy and deploy cleanup, build the proposal
    function _build(Addresses) internal virtual {}

    // @dev Actually run the proposal (e.g. queue actions in the Timelock,
    // or execute a serie of Multisig calls...).
    // See proposals/proposalTypes for helper contracts.
    // address param is the address of the proposal executor
    function _run(Addresses, address) internal virtual {
	revert("You must override the run function");
    }

    // @dev After a proposal executed, if you mocked some behavior in the
    // afterDeploy step, you might want to tear down the mocks here.
    // For instance, in afterDeploy() you could impersonate the multisig
    // of another protocol to do actions in their protocol (in anticipation
    // of changes that must happen before your proposal execution), and here
    // you could revert these changes, to make sure the integration tests
    // run on a state that is as close to mainnet as possible.
    function _teardown(Addresses, address) internal virtual {}

    // @dev For small post-proposal checks, e.g. read state variables of the
    // contracts you deployed, to make sure your deploy() and afterDeploy()
    // steps have deployed contracts in a correct configuration, or read
    // states that are expected to have change during your run() step.
    // Note that there is a set of tests that run post-proposal in
    // contracts/test/integration/post-proposal-checks, as well as
    // tests that read state before proposals & after, in
    // contracts/test/integration/proposal-checks, so this validate()
    // step should only be used for small checks.
    // If you want to add extensive validation of a new component
    // deployed by your proposal, you might want to add a post-proposal
    // test file instead.
    function _validate(Addresses, address) internal virtual {}
}
