// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {MockToken} from "mocks/MockToken.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

contract MultisigProposal_01 is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MOCK_MULTISIG_PROPOSAL_01";
    }

    function description() public pure override returns (string memory) {
        return "Mock multisig proposal 01";
    }

    function run() public override {
        super.run();
    }

    function deploy() public override {
        if (!addresses.isAddressSet("TOKEN")) {
            MockToken mockERC20 = new MockToken("MOCK_TOKEN", "MTOKEN");

            mockERC20.mint(
                addresses.getAddress("PROTOCOL_MULTISIG"), 1000 ether
            );

            addresses.addAddress("TOKEN", address(mockERC20), true);
        }
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_MULTISIG"))
    {
        MockToken mockToken = MockToken(addresses.getAddress("TOKEN"));
        address deployer = addresses.getAddress("DEPLOYER_EOA");

        // Actions
        mockToken.approve(deployer, 200);
        mockToken.transfer(deployer, 500);
        mockToken.transfer(deployer, 100);
        mockToken.approve(addresses.getAddress("PROTOCOL_MULTISIG"), 200);
        mockToken.transferFrom(
            addresses.getAddress("PROTOCOL_MULTISIG"), deployer, 200
        );
    }
}
