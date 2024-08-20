pragma solidity ^0.8.0;

import "forge-std/mocks/MockERC20.sol";

import {MockAuction} from "mocks/MockAuction.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

contract MultisigProposal_04 is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MOCK_MULTISIG_PROPOSAL_04";
    }

    function description() public pure override returns (string memory) {
        return "Mock multisig proposal 04";
    }

    function run() public override {
        super.run();
    }

    function deploy() public override {
        MockAuction auctionContract = new MockAuction();

        // mint 100 eth to multisig contract
        vm.deal(addresses.getAddress("PROTOCOL_MULTISIG"), 1000 ether);

        // add Voting contract address
        addresses.addAddress("AUCTION_CONTRACT", address(auctionContract), true);
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_MULTISIG"))
    {
        MockAuction auctionContract =
            MockAuction(addresses.getAddress("AUCTION_CONTRACT"));

        // actions
        auctionContract.bid{value: 10 ether}();
        auctionContract.bid{value: 40 ether}();
        auctionContract.bid{value: 50 ether}();
        auctionContract.bid{value: 90 ether}();
        auctionContract.bid{value: 100 ether}();
    }
}
