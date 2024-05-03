// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {console} from "@forge-std/console.sol";
import {Test} from "@forge-std/Test.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {IProposal} from "@proposals/IProposal.sol";
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

    constructor() Proposal("./addresses/Addresses.json", "DEPLOYER_EOA") {}

    function deploy() public override {
        if (!addresses.isAddressSet("VAULT")) {
            Vault timelockVault = new Vault();
            addresses.changeAddress("VAULT", address(timelockVault), true);
        }

        if (!addresses.isAddressSet("TOKEN_1")) {
            Token token = new Token();
            addresses.changeAddress("TOKEN_1", address(token), true);
        }
    }

    function build() public override buildModifier {
        address timelock = addresses.getAddress("PROTOCOL_TIMELOCK");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        Token token = Token(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(timelock);
        token.transferOwnership(timelock);
        token.transfer(
            timelock,
            token.balanceOf(addresses.getAddress("DEPLOYER_EOA"))
        );
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
            addresses.getAddress("DEPLOYER_EOA")
        );

        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        // check that the proposal targets are correct
        assertEq(targets.length, 3);
        assertEq(targets[0], addresses.getAddress("VAULT"));
        assertEq(targets[1], addresses.getAddress("TOKEN_1"));
        assertEq(targets[2], addresses.getAddress("TOKEN_1"));

        // check that the proposal values are correct
        assertEq(values.length, 3);
        assertEq(values[0], 0);
        assertEq(values[1], 0);
        assertEq(values[2], 0);

        // check that the proposal calldatas are correct
        assertEq(calldatas.length, 3);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "transferOwnership(address)",
                addresses.getAddress("PROTOCOL_TIMELOCK")
            )
        );
        assertEq(
            calldatas[1],
            abi.encodeWithSignature(
                "transferOwnership(address)",
                addresses.getAddress("PROTOCOL_TIMELOCK")
            )
        );
        assertEq(
            calldatas[2],
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                addresses.getAddress("PROTOCOL_TIMELOCK"),
                expectedBalance
            )
        );
    }
}
