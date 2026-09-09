// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "@forge-std/Test.sol";

import {Addresses} from "@addresses/Addresses.sol";

import {MockMultisigProposal} from "@mocks/MockMultisigProposal.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";
import {Constants} from "@utils/Constants.sol";

contract MultisigProposalIntegrationTest is Test {
    Addresses public addresses;
    MultisigProposal public proposal;

    function setUp() public {
        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 1;

        // Instantiate the Addresses contract
        addresses = new Addresses("./addresses", chainIds);
        vm.makePersistent(address(addresses));

        // Instantiate the MultisigProposal contract
        proposal = MultisigProposal(new MockMultisigProposal());

        proposal.setPrimaryForkId(vm.createSelectFork("mainnet"));

        // Set the addresses contract
        proposal.setAddresses(addresses);
    }

    function test_setUp() public view {
        assertEq(
            proposal.name(),
            string("OPTMISM_MULTISIG_MOCK"),
            "Wrong proposal name"
        );
        assertEq(
            proposal.description(),
            string("Mock proposal that upgrade the L1 NFT Bridge"),
            "Wrong proposal description"
        );
    }

    function test_deploy() public {
        vm.startPrank(addresses.getAddress("DEPLOYER_EOA"));
        proposal.deploy();
        vm.stopPrank();

        assertTrue(
            addresses.isAddressSet("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")
        );
    }

    function test_build() public {
        test_deploy();

        vm.expectRevert("No actions found");
        proposal.getProposalActions();

        proposal.build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        // check that the proposal targets are correct
        assertEq(targets.length, 1, "Wrong targets length");
        assertEq(
            targets[0],
            addresses.getAddress("OPTIMISM_PROXY_ADMIN"),
            "Wrong target at index 0"
        );

        // check that the proposal values are correct
        assertEq(values.length, 1, "Wrong values length");
        assertEq(values[0], 0, "Wrong value at index 0");

        // check that the proposal calldatas are correct
        assertEq(calldatas.length, 1);
        assertEq(
            calldatas[0],
            abi.encodeWithSignature(
                "upgrade(address,address)",
                addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_PROXY"),
                addresses.getAddress("OPTIMISM_L1_NFT_BRIDGE_IMPLEMENTATION")
            ),
            "Wrong calldata at index 0"
        );
    }

    function test_simulate() public {
        test_build();

        proposal.simulate();

        proposal.validate();
    }

    function test_getCalldata() public {
        test_build();

        (
            address[] memory targets,
            uint256[] memory values,
            bytes[] memory calldatas
        ) = proposal.getProposalActions();

        bytes memory encodedTxs;

        for (uint256 i = 0; i < targets.length; i++) {
            uint8 operation = 0;
            address to = targets[i];
            uint256 value = values[i];
            bytes memory callData = calldatas[i];

            encodedTxs = bytes.concat(
                encodedTxs,
                abi.encodePacked(
                    operation, to, value, uint256(callData.length), callData
                )
            );
        }

        bytes memory expectedData =
            abi.encodeWithSignature("multiSend(bytes)", encodedTxs);

        bytes memory data = proposal.getCalldata();

        assertEq(data, expectedData, "Wrong multiSend calldata");
    }

    function test_defaultBehaviorRemainsAllRegularCalls() public {
        (MockAllCallMultisigProposal allCallProposal,,,) =
            _createAllCallProposal();

        allCallProposal.build();

        bytes memory transactions =
            _decodeMultiSendTransactions(allCallProposal.getCalldata());

        assertEq(
            _operationAt(transactions, 0), Constants.CALL, "Wrong operation 0"
        );
        assertEq(
            _operationAt(transactions, 1), Constants.CALL, "Wrong operation 1"
        );
    }

    function test_getCalldataWithDelegateCallProposal() public {
        (MockDelegateCallMultisigProposal delegateCallProposal,,,,) =
            _createDelegateCallProposal();

        delegateCallProposal.build();

        bytes memory transactions =
            _decodeMultiSendTransactions(delegateCallProposal.getCalldata());

        assertEq(
            _operationAt(transactions, 0),
            Constants.DELEGATE_CALL,
            "Wrong operation 0"
        );
        assertEq(
            _operationAt(transactions, 1),
            Constants.DELEGATE_CALL,
            "Wrong operation 1"
        );
        assertEq(
            _operationAt(transactions, 2),
            Constants.DELEGATE_CALL,
            "Wrong operation 2"
        );
    }

    function test_getSafeTransactionUsesCallOnlyMultiSendForCalls() public {
        test_build();

        (address to, uint256 value, bytes memory data, uint8 operation) =
            proposal.getSafeTransaction();

        assertEq(to, Constants.SAFE_MULTISEND_CALL_ONLY_CONTRACT);
        assertEq(value, 0);
        assertEq(data, proposal.getCalldata());
        assertEq(operation, Constants.DELEGATE_CALL);
    }

    function test_getSafeTransactionUsesMultiSendForDelegateCall() public {
        (MockDelegateCallMultisigProposal delegateCallProposal,,,,) =
            _createDelegateCallProposal();
        delegateCallProposal.build();

        (address to, uint256 value, bytes memory data, uint8 operation) =
            delegateCallProposal.getSafeTransaction();

        assertEq(to, Constants.SAFE_MULTISEND_CONTRACT);
        assertEq(value, 0);
        assertEq(data, delegateCallProposal.getCalldata());
        assertEq(operation, Constants.DELEGATE_CALL);
    }

    function test_simulateDelegateCallProposal() public {
        (
            MockDelegateCallMultisigProposal delegateCallProposal,
            MockOperationTarget target,
            address multisig,
            bytes32 delegateSlot,
            bytes32 delegateValue
        ) = _createDelegateCallProposal();

        delegateCallProposal.build();
        bytes memory originalBytecode = multisig.code;

        delegateCallProposal.simulate();

        assertEq(
            target.callSender(),
            address(0),
            "Delegatecall unexpectedly wrote target sender"
        );
        assertEq(
            target.callNumber(),
            0,
            "Delegatecall unexpectedly wrote target number"
        );
        assertEq(
            vm.load(multisig, bytes32(uint256(0))),
            bytes32(uint256(uint160(multisig))),
            "Delegatecall did not write sender to multisig storage"
        );
        assertEq(
            vm.load(multisig, bytes32(uint256(1))),
            bytes32(uint256(22)),
            "Delegatecall did not write number to multisig storage"
        );
        assertEq(
            vm.load(multisig, delegateSlot),
            delegateValue,
            "Delegatecall did not write to multisig storage"
        );
        assertEq(
            keccak256(multisig.code),
            keccak256(originalBytecode),
            "Multisig bytecode not restored"
        );
    }

    function test_getProposalId() public {
        vm.expectRevert("Not implemented");
        proposal.getProposalId();
    }

    function _createAllCallProposal()
        internal
        returns (
            MockAllCallMultisigProposal allCallProposal,
            MockOperationTarget target,
            address multisig,
            bytes32 delegateSlot
        )
    {
        target = new MockOperationTarget();
        multisig = makeAddr("all-call-multisig");
        delegateSlot = bytes32(
            uint256(
                0xc994e5c8cb6ad18093f6587495d184e653364d389286548632493e7d9afcb54e
            )
        );
        allCallProposal = new MockAllCallMultisigProposal(
            multisig, target, delegateSlot, bytes32(uint256(1))
        );
    }

    function _createDelegateCallProposal()
        internal
        returns (
            MockDelegateCallMultisigProposal delegateCallProposal,
            MockOperationTarget target,
            address multisig,
            bytes32 delegateSlot,
            bytes32 delegateValue
        )
    {
        target = new MockOperationTarget();
        multisig = addresses.getAddress("OPTIMISM_MULTISIG");
        delegateSlot = bytes32(
            uint256(
                0x828ef5eca6cf52a2ad4383abe23d27fbd33270d45147bceaaeaef0e8d12791a4
            )
        );
        delegateValue = bytes32(uint256(0x1234));
        delegateCallProposal = new MockDelegateCallMultisigProposal(
            multisig, target, delegateSlot, delegateValue
        );
    }

    function _decodeMultiSendTransactions(bytes memory data)
        internal
        pure
        returns (bytes memory)
    {
        bytes4 selector = bytes4(data);
        require(
            selector == bytes4(keccak256("multiSend(bytes)")), "Wrong selector"
        );

        bytes memory encodedParams = new bytes(data.length - 4);
        for (uint256 i = 0; i < encodedParams.length; i++) {
            encodedParams[i] = data[i + 4];
        }

        return abi.decode(encodedParams, (bytes));
    }

    function _operationAt(bytes memory transactions, uint256 actionIndex)
        internal
        pure
        returns (uint8 operation)
    {
        uint256 offset;

        for (uint256 i = 0; i <= actionIndex; i++) {
            operation = uint8(transactions[offset]);

            if (i == actionIndex) {
                return operation;
            }

            uint256 dataLength = _readUint256(transactions, offset + 53);
            offset += 85 + dataLength;
        }
    }

    function _readUint256(bytes memory data, uint256 offset)
        internal
        pure
        returns (uint256 value)
    {
        require(data.length >= offset + 32, "Read out of bounds");

        assembly {
            value := mload(add(add(data, 0x20), offset))
        }
    }
}

contract MockOperationTarget {
    address public callSender;
    uint256 public callNumber;

    function recordCall(uint256 number) external {
        callSender = msg.sender;
        callNumber = number;
    }

    function writeSlot(bytes32 slot, bytes32 value) external {
        assembly {
            sstore(slot, value)
        }
    }
}

contract MockAllCallMultisigProposal is MultisigProposal {
    address public multisig;
    MockOperationTarget public target;
    bytes32 public delegateSlot;
    bytes32 public delegateValue;

    constructor(
        address _multisig,
        MockOperationTarget _target,
        bytes32 _delegateSlot,
        bytes32 _delegateValue
    ) {
        multisig = _multisig;
        target = _target;
        delegateSlot = _delegateSlot;
        delegateValue = _delegateValue;
    }

    function name() public pure virtual override returns (string memory) {
        return "ALL_CALL_MULTISIG_MOCK";
    }

    function description()
        public
        pure
        virtual
        override
        returns (string memory)
    {
        return "Mock all-call multisig proposal";
    }

    function build() public virtual override buildModifier(multisig) {
        target.recordCall(11);
        target.writeSlot(delegateSlot, delegateValue);
    }
}

contract MockDelegateCallMultisigProposal is MockAllCallMultisigProposal {
    constructor(
        address _multisig,
        MockOperationTarget _target,
        bytes32 _delegateSlot,
        bytes32 _delegateValue
    )
        MockAllCallMultisigProposal(
            _multisig, _target, _delegateSlot, _delegateValue
        )
    {}

    function name() public pure override returns (string memory) {
        return "DELEGATE_CALL_MULTISIG_MOCK";
    }

    function description() public pure override returns (string memory) {
        return "Mock delegatecall multisig proposal";
    }

    function build() public override buildModifier(multisig) {
        target.recordCall(11);
        target.writeSlot(delegateSlot, delegateValue);
        target.recordCall(22);
    }

    function isDelegateCall() public pure override returns (bool) {
        return true;
    }

    function simulate() public override {
        _simulateActions(multisig);
    }
}
