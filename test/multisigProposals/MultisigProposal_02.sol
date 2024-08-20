pragma solidity ^0.8.0;

import {MockToken} from "mocks/MockToken.sol";

import {MockTokenWrapper} from "mocks/MockTokenWrapper.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

contract MultisigProposal_02 is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MOCK_MULTISIG_PROPOSAL_02";
    }

    function description() public pure override returns (string memory) {
        return "Mock multisig proposal 02";
    }

    function run() public override {
        super.run();
    }

    function deploy() public override {
        address multisig = addresses.getAddress("PROTOCOL_MULTISIG");

        // mint 100 eth to multisig contract
        vm.deal(multisig, 100 ether);

        MockToken token = MockToken(addresses.getAddress("TOKEN"));

        MockTokenWrapper tokenWrapper =
            new MockTokenWrapper(addresses.getAddress("TOKEN"));

        token.mint(addresses.getAddress("DEPLOYER_EOA"), 1000 ether);

        // transfer 100 tokens to token wrapper contract
        token.transfer(address(tokenWrapper), 100 ether);

        // add TOKEN_WRAPPER address
        addresses.addAddress("TOKEN_WRAPPER", address(tokenWrapper), true);
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_MULTISIG"))
    {
        MockTokenWrapper tokenWrapper =
            MockTokenWrapper(addresses.getAddress("TOKEN_WRAPPER"));

        // actions
        MockToken(addresses.getAddress("TOKEN")).approve(
            address(tokenWrapper), 60 ether
        );
        tokenWrapper.mint{value: 10 ether}();
        tokenWrapper.redeemTokens(10 ether);
        tokenWrapper.mint{value: 20 ether}();
        tokenWrapper.mint{value: 30 ether}();
        tokenWrapper.redeemTokens(50 ether);
        tokenWrapper.mint{value: 40 ether}();
        tokenWrapper.mint{value: 50 ether}();
    }
}
