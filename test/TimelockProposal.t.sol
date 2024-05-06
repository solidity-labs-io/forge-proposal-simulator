// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";
import {console} from "@forge-std/console.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Proposal} from "@proposals/Proposal.sol";
import {TimelockProposal} from "@proposals/TimelockProposal.sol";
import {Vault} from "@mocks/Vault.sol";
import {Token} from "@mocks/Token.sol";

contract MockTimelockProposal is TimelockProposal {
    function name() public pure override returns (string memory) {
        return "TIMELOCK_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Timelock proposal mock";
    }

    constructor() Proposal("./addresses/Addresses.json", "DEPLOYER_EOA") {
        timelock = payable(addresses.getAddress("PROTOCOL_TIMELOCK"));
    }

    function deploy() public override {
        if (!addresses.isAddressSet("VAULT")) {
            Vault timelockVault = new Vault();

            addresses.changeAddress("VAULT", address(timelockVault), true);

            timelockVault.transferOwnership(address(timelock));
        }

        if (!addresses.isAddressSet("TOKEN_1")) {
            Token token = new Token();
            addresses.changeAddress("TOKEN_1", address(token), true);

            token.transferOwnership(timelock);
            token.transfer(
                address(timelock),
                token.balanceOf(addresses.getAddress("DEPLOYER_EOA"))
            );
        }
    }

    function build() public override buildModifier(timelock) {
        /// STATICCALL -- not recorded for the run stage
        address timelockVault = addresses.getAddress("VAULT");
        address token = addresses.getAddress("TOKEN_1");
        uint256 balance = Token(token).balanceOf(address(timelock));

        Vault(timelockVault).whitelistToken(token, true);

        /// CALLS -- mutative and recorded
        Token(token).approve(timelockVault, balance);
        Vault(timelockVault).deposit(token, balance);
    }

    /// @notice Executes the proposal actions.
    function simulate() public override {
        /// Call parent simulate function to check if there are actions to execute
        super.simulate();

        address dev = addresses.getAddress("DEPLOYER_EOA");

        /// Dev is proposer and executor
        _simulateActions(dev, dev);
    }
}

contract TimelockProposalUnitTest is Test {
    Addresses public addresses;
    Proposal public proposal;

    function setUp() public {
        proposal = Proposal(new MockTimelockProposal());
        addresses = proposal.addresses();
    }

    function test_build() public {
        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        Token token = Token(addresses.getAddress("TOKEN_1"));

        uint256 expectedBalance = token.balanceOf(
            addresses.getAddress("PROTOCOL_TIMELOCK")
        );

        proposal.build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        // check that the proposal targets are correct
        assertEq(targets.length, 3, "Wrong targets length");
        assertEq(
            targets[0],
            addresses.getAddress("VAULT"),
            "Wrong target at index 0"
        );
        assertEq(
            targets[1],
            addresses.getAddress("TOKEN_1"),
            "Wrong target at index 1"
        );
        assertEq(
            targets[2],
            addresses.getAddress("VAULT"),
            "Wrong target at index 2"
        );

        // check that the proposal values are correct
        assertEq(values.length, 3, "Wrong values length");
        assertEq(values[0], 0, "Wrong value at index 0");
        assertEq(values[1], 0, "Wrong value at index 1");
        assertEq(values[2], 0, "Wrong value at index 2");

        // check that the proposal calldatas are correct
        assertEq(calldatas.length, 3);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "whitelistToken(address,bool)",
                addresses.getAddress("TOKEN_1"),
                true
            ),
            "Wrong calldata at index 0"
        );
        assertEq(
            calldatas[1],
            abi.encodeWithSignature(
                "approve(address,uint256)",
                addresses.getAddress("VAULT"),
                expectedBalance
            ),
            "Wrong calldata at index 1"
        );
        assertEq(
            calldatas[2],
            abi.encodeWithSignature(
                "deposit(address,uint256)",
                addresses.getAddress("TOKEN_1"),
                expectedBalance
            ),
            "Wrong calldata at index 2"
        );
    }

    function test_simulate() public {
        test_build();

        proposal.simulate();

        // check that proposal exists
        assertTrue(
            proposal.checkOnChainCalldata(
                addresses.getAddress("PROTOCOL_TIMELOCK")
            )
        );

        // check that the proposal actions were executed
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        Token token = Token(addresses.getAddress("TOKEN_1"));

        assertEq(
            timelockVault.owner(),
            addresses.getAddress("PROTOCOL_TIMELOCK"),
            "Wrong owner"
        );

        assertTrue(
            timelockVault.tokenWhitelist(addresses.getAddress("TOKEN_1")),
            "Token not whitelisted"
        );

        assertEq(
            token.balanceOf(addresses.getAddress("VAULT")),
            token.totalSupply(),
            "Wrong token balance"
        );
    }
}
