// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {MultisigProposal_01} from
    "@test/multisigProposals/MultisigProposal_01.sol";
import {MultisigProposal_02} from
    "@test/multisigProposals/MultisigProposal_02.sol";
import {MultisigProposal_03} from
    "@test/multisigProposals/MultisigProposal_03.sol";
import {MultisigProposal_04} from
    "@test/multisigProposals/MultisigProposal_04.sol";
import {MultisigProposal_05} from
    "@test/multisigProposals/MultisigProposal_05.sol";

contract MultisigProposalCalldataTest is Test {
    Addresses public addresses;
    address[] public proposals;

    function setUp() public {
        // Instantiate the Addresses contract
        string memory addressesFolderPath = "./addresses";
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 31337;
        addresses = new Addresses(addressesFolderPath, chainIds);

        // Instantiate the MultisigProposal contracts
        address proposal = address(new MultisigProposal_01());
        proposals.push(proposal);

        proposal = address(new MultisigProposal_02());
        proposals.push(proposal);

        proposal = address(new MultisigProposal_03());
        proposals.push(proposal);

        proposal = address(new MultisigProposal_04());
        proposals.push(proposal);

        proposal = address(new MultisigProposal_05());
        proposals.push(proposal);

        for (uint256 i; i < proposals.length; ++i) {
            MultisigProposal(proposals[i]).setAddresses(addresses);
            MultisigProposal(proposals[i]).run();
        }
    }

    function test_targets() public view {
        for (uint256 i; i < proposals.length; ++i) {
            (address[] memory targets,,) =
                MultisigProposal(proposals[i]).getProposalActions();

            (address[] memory expectedTargets,,) = getProposalDetail(i);

            // check that the proposal targets are correct
            assertEq(
                targets.length, expectedTargets.length, "Wrong targets length"
            );

            for (uint256 j; j < targets.length; ++j) {
                assertEq(targets[j], expectedTargets[j], "Incorrect target");
            }
        }
    }

    function test_calldata() public view {
        for (uint256 i; i < proposals.length; ++i) {
            (,, bytes[] memory calldatas) =
                MultisigProposal(proposals[i]).getProposalActions();

            (,, bytes[] memory expectedCalldatas) = getProposalDetail(i);

            // check that the proposal calldatas are correct
            assertEq(
                calldatas.length,
                expectedCalldatas.length,
                "Wrong calldatas length"
            );

            for (uint256 j; j < calldatas.length; ++j) {
                assertEq(
                    calldatas[j], expectedCalldatas[j], "Incorrect calldata"
                );
            }
        }
    }

    function test_value() public view {
        for (uint256 i; i < proposals.length; ++i) {
            (, uint256[] memory values,) =
                MultisigProposal(proposals[i]).getProposalActions();

            (, uint256[] memory expectedValues,) = getProposalDetail(i);

            // check that the proposal values are correct
            assertEq(
                values.length, expectedValues.length, "Wrong values length"
            );

            for (uint256 j; j < values.length; ++j) {
                assertEq(values[j], expectedValues[j], "Incorrect value");
            }
        }
    }

    function getProposalDetail(uint256 proposalIndex)
        public
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        if (proposalIndex == 0) {
            return getFirstProposalDetail();
        } else if (proposalIndex == 1) {
            return getSecondProposalDetail();
        } else if (proposalIndex == 2) {
            return getThirdProposalDetail();
        } else if (proposalIndex == 3) {
            return getFourthProposalDetail();
        } else {
            return getFifthProposalDetail();
        }
    }

    function getFirstProposalDetail()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        targets = new address[](5);
        values = new uint256[](5);
        calldatas = new bytes[](5);

        address mockToken = addresses.getAddress("TOKEN");

        targets[0] = mockToken;
        calldatas[0] = abi.encodeWithSignature(
            "approve(address,uint256)",
            addresses.getAddress("DEPLOYER_EOA"),
            200
        );
        values[0] = 0;

        targets[1] = mockToken;
        calldatas[1] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            addresses.getAddress("DEPLOYER_EOA"),
            500
        );
        values[1] = 0;

        targets[2] = mockToken;
        calldatas[2] = abi.encodeWithSignature(
            "transfer(address,uint256)",
            addresses.getAddress("DEPLOYER_EOA"),
            100
        );
        values[2] = 0;

        targets[3] = mockToken;
        calldatas[3] = abi.encodeWithSignature(
            "approve(address,uint256)",
            addresses.getAddress("PROTOCOL_MULTISIG"),
            200
        );
        values[3] = 0;

        targets[4] = mockToken;
        calldatas[4] = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)",
            addresses.getAddress("PROTOCOL_MULTISIG"),
            addresses.getAddress("DEPLOYER_EOA"),
            200
        );
        values[4] = 0;
    }

    function getSecondProposalDetail()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        targets = new address[](8);
        values = new uint256[](8);
        calldatas = new bytes[](8);
        address tokenWrapper = addresses.getAddress("TOKEN_WRAPPER");

        targets[0] = addresses.getAddress("TOKEN");
        calldatas[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(tokenWrapper), 60 ether
        );
        values[0] = 0;

        targets[1] = tokenWrapper;
        calldatas[1] = abi.encodeWithSignature("mint()");
        values[1] = 10 ether;

        targets[2] = tokenWrapper;
        calldatas[2] =
            abi.encodeWithSignature("redeemTokens(uint256)", 10 ether);
        values[2] = 0;

        targets[3] = tokenWrapper;
        calldatas[3] = abi.encodeWithSignature("mint()");
        values[3] = 20 ether;

        targets[4] = tokenWrapper;
        calldatas[4] = abi.encodeWithSignature("mint()");
        values[4] = 30 ether;

        targets[5] = tokenWrapper;
        calldatas[5] =
            abi.encodeWithSignature("redeemTokens(uint256)", 50 ether);
        values[5] = 0;

        targets[6] = tokenWrapper;
        calldatas[6] = abi.encodeWithSignature("mint()");
        values[6] = 40 ether;

        targets[7] = tokenWrapper;
        calldatas[7] = abi.encodeWithSignature("mint()");
        values[7] = 50 ether;
    }

    function getThirdProposalDetail()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        targets = new address[](7);
        values = new uint256[](7);
        calldatas = new bytes[](7);

        address votingContract = addresses.getAddress("VOTING_CONTRACT");

        targets[0] = votingContract;
        calldatas[0] = abi.encodeWithSignature("vote(string)", "candidate0");
        values[0] = 0;

        targets[1] = votingContract;
        calldatas[1] = abi.encodeWithSignature("vote(string)", "candidate2");
        values[1] = 0;

        targets[2] = votingContract;
        calldatas[2] = abi.encodeWithSignature("vote(string)", "candidate4");
        values[2] = 0;

        targets[3] = votingContract;
        calldatas[3] = abi.encodeWithSignature("vote(string)", "candidate7");
        values[3] = 0;

        targets[4] = votingContract;
        calldatas[4] = abi.encodeWithSignature("vote(string)", "candidate9");
        values[4] = 0;

        targets[5] = votingContract;
        calldatas[5] = abi.encodeWithSignature("vote(string)", "candidate5");
        values[5] = 0;

        targets[6] = votingContract;
        calldatas[6] = abi.encodeWithSignature("vote(string)", "candidate8");
        values[6] = 0;
    }

    function getFourthProposalDetail()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        targets = new address[](5);
        values = new uint256[](5);
        calldatas = new bytes[](5);

        address auctionContract = addresses.getAddress("AUCTION_CONTRACT");

        targets[0] = auctionContract;
        calldatas[0] = abi.encodeWithSignature("bid()");
        values[0] = 10 ether;

        targets[1] = auctionContract;
        calldatas[1] = abi.encodeWithSignature("bid()");
        values[1] = 40 ether;

        targets[2] = auctionContract;
        calldatas[2] = abi.encodeWithSignature("bid()");
        values[2] = 50 ether;

        targets[3] = auctionContract;
        calldatas[3] = abi.encodeWithSignature("bid()");
        values[3] = 90 ether;

        targets[4] = auctionContract;
        calldatas[4] = abi.encodeWithSignature("bid()");
        values[4] = 100 ether;
    }

    function getFifthProposalDetail()
        internal
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        )
    {
        targets = new address[](7);
        values = new uint256[](7);
        calldatas = new bytes[](7);

        address savingContract = addresses.getAddress("SAVING_CONTRACT");

        targets[0] = savingContract;
        calldatas[0] = abi.encodeWithSignature("deposit(uint256)", 0);
        values[0] = 20 ether;

        targets[1] = savingContract;
        calldatas[1] = abi.encodeWithSignature("deposit(uint256)", 20 days);
        values[1] = 40 ether;

        targets[2] = savingContract;
        calldatas[2] = abi.encodeWithSignature("withdraw(uint256)", 0);
        values[2] = 0;

        targets[3] = savingContract;
        calldatas[3] = abi.encodeWithSignature("deposit(uint256)", 0);
        values[3] = 60 ether;

        targets[4] = savingContract;
        calldatas[4] = abi.encodeWithSignature("deposit(uint256)", 60 days);
        values[4] = 80 ether;

        targets[5] = savingContract;
        calldatas[5] = abi.encodeWithSignature("deposit(uint256)", 90 days);
        values[5] = 100 ether;

        targets[6] = savingContract;
        calldatas[6] = abi.encodeWithSignature("withdraw(uint256)", 2);
        values[6] = 0;
    }
}
