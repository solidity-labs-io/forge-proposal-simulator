# Multisig Proposal

After adding FPS into project dependencies, the next step involves initiating the creation of the first Proposal contract. This example provides guidance on formulating a proposal for deploying new instances of `Vault.sol` and `MockToken`. These contracts are located in the [guides section](./introduction.md#example-contracts). The proposal includes the transfer of ownership of both contracts to a multisig wallet, along with the whitelisting of the token and minting of tokens to the multisig.

Proposal files are located in the `proposals` folder. Create a new file called `MULTISIG_01.sol` and add the following code:

```solidity
pragma solidity ^0.8.0;

import {Vault} from "@examples/Vault.sol";
import {MockToken} from "@examples/MockToken.sol";
import {Addresses} from "@addresses/Addresses.sol";
import {MultisigProposal} from "@proposals/MultisigProposal.sol";

// MULTISIG_01 proposal deploys a Vault contract and an ERC20 token contract
// Then the proposal transfers ownership of both Vault and ERC20 to the multisig address
// Finally the proposal whitelist the ERC20 token in the Vault contract
contract MULTISIG_01 is MultisigProposal {
    // Returns the name of the proposal.
    function name() public pure override returns (string memory) {
        return "MULTISIG_01";
    }

    // Provides a brief description of the proposal.
    function description() public pure override returns (string memory) {
        return "Deploy Vault contract";
    }

    /// @notice Deploys a vault contract and an ERC20 token contract.
    /// @param addresses The addresses contract.
    function _deploy(Addresses addresses, address) internal override {
        if (!addresses.isAddressSet("VAULT")) {
            Vault timelockVault = new Vault();
            addresses.addAddress("VAULT", address(timelockVault), true);
        }

        if (!addresses.isAddressSet("TOKEN_1")) {
            MockToken token = new MockToken();
            addresses.addAddress("TOKEN_1", address(token), true);
        }
    }

    /// @notice proposal action steps:
    /// 1. Transfers vault ownership to dev multisig.
    /// 2. Transfer token ownership to dev multisig.
    /// 3. Transfers all tokens to dev multisig.
    /// @param addresses The addresses contract.
    function _afterDeploy(
        Addresses addresses,
        address deployer
    ) internal override {
        address devMultisig = addresses.getAddress("DEV_MULTISIG");
        Vault timelockVault = Vault(addresses.getAddress("VAULT"));
        MockToken token = MockToken(addresses.getAddress("TOKEN_1"));

        timelockVault.transferOwnership(devMultisig);
        token.transferOwnership(devMultisig);
        token.transfer(devMultisig, token.balanceOf(address(deployer)));
    }

    /// @notice Sets up actions for the proposal, in this case, setting the MockToken to active.
    /// @param addresses The addresses contract.
data:
  0x252dba4200000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000090193c961a926261b756d1e5bb255e67ff9498a1000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000440ffb1d8b000000000000000000000000a8452ec99ce0c64f20701db7dd3abdb607c00496000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000
  Multicall result:
  0x00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000
  Addresses added after running proposals:
  VAULT 0x90193C961A926261B756D1E5bb255e67ff9498A1
  TOKEN_1 0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496
```

A signer from the multisig address can check whether the calldata proposed on the multisig matches the calldata obtained from the call. It is important to note that two new addresses have been added to the `Addresses.sol` storage. These addresses are not included in the JSON file and must be added manually for accuracy.
