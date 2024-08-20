pragma solidity ^0.8.0;

import "forge-std/mocks/MockERC20.sol";

import {MockSavingContract} from "mocks/MockSavingContract.sol";

import {MultisigProposal} from "@proposals/MultisigProposal.sol";

contract MultisigProposal_05 is MultisigProposal {
    function name() public pure override returns (string memory) {
        return "MOCK_MULTISIG_PROPOSAL_05";
    }

    function description() public pure override returns (string memory) {
        return "Mock multisig proposal 05";
    }

    function run() public override {
        super.run();
    }

    function deploy() public override {
        MockSavingContract savingContract = new MockSavingContract();

        // mint 100 eth to multisig contract
        vm.deal(addresses.getAddress("PROTOCOL_MULTISIG"), 1000 ether);

        // add Voting contract address
        addresses.addAddress("SAVING_CONTRACT", address(savingContract), true);
    }

    function build()
        public
        override
        buildModifier(addresses.getAddress("PROTOCOL_MULTISIG"))
    {
        MockSavingContract savingContract =
            MockSavingContract(addresses.getAddress("SAVING_CONTRACT"));

        // actions
        savingContract.deposit{value: 20 ether}(0);
        savingContract.deposit{value: 40 ether}(20 days);
        savingContract.withdraw(0);
        savingContract.deposit{value: 60 ether}(0);
        savingContract.deposit{value: 80 ether}(60 days);
        savingContract.deposit{value: 100 ether}(90 days);
        savingContract.withdraw(2);
    }
}
