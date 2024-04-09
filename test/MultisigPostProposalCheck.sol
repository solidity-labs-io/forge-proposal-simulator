pragma solidity ^0.8.0;

import "@forge-std/Test.sol";

import {Constants} from "@utils/Constants.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {Proposal} from "@proposals/Proposal.sol";

/// @notice this is a helper contract to execute a proposal before running integration tests.
/// @dev should be inherited by integration test contracts.
contract MultisigPostProposalCheck is Test {
    Proposal public proposal;
    Addresses public addresses;

    function setUp() public virtual {
        require(
            address(proposal) != address(0),
            "Test must override setUp and set the proposal contract"
        );
        addresses = proposal.addresses();

        /// @dev Verify if the multisig address is a contract; if it is not
        /// (e.g. running on a empty blockchain node), set the multisig
        /// code to Safe Multisig code
        /// Note: This approach is a workaround for this example where
        /// a deployed multisig contract isn't available. In real-world applications,
        /// you'd typically have a multisig contract in place. Use this code
        /// only as a reference
        bool isContract = addresses.isAddressContract("DEV_MULTISIG");
        address multisig;
        if (!isContract) {
            multisig = addresses.getAddress("DEV_MULTISIG");
            uint256 multisigSize;
            assembly {
                multisigSize := extcodesize(multisig)
            }
            if (multisigSize == 0) {
                vm.etch(multisig, Constants.SAFE_BYTECODE);
            }
        } else {
            multisig = addresses.getAddress("DEV_MULTISIG");
        }

        proposal.run();
    }
}
