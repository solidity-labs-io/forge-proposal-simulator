// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

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

    constructor() Proposal("./addresses/Addresses.json") {
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
