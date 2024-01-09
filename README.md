# Overview

The Forge Proposal Simulator (FPS) offers a framework for creating secure governance proposals and deployment scripts, enhancing safety, and ensuring protocol health throughout the proposal lifecycle. The major benefits of using this tool are standardization of proposals, safe calldata generation, and preventing deployment parameterization and governance action bugs.

For guidance on how to use the library please check FPS [documentation](https://solidity-labs.gitbook.io/forge-proposal-simulator/)

## Usage

1. Integrate this library into your protocol repository as a submodule:

    ```bash
    forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
    ```

2. Add the follow remapping to your `remappings.txt` file:

```txt
@forge-proposal-simulator=/lib/forge-proposal-simulator/
```

3. For testing a governance proposal, create a contract inheriting one of the proposal types from our [proposals](./proposals) directory. Omit any actions that are not relevant to your proposal.

4. Generate a JSON file listing the addresses and names of your deployed contracts. Refer to [Addresses.json](./addresses/Address.json) for details.

5. Create scripts and/or tests using the guides on [FPS documentation](https://solidity-labs.gitbook.io/forge-proposal-simulator/)

## Contribute

There are many ways you can participate and help build high quality software. Check out the [contribution guide](CONTRIBUTING.md)!

## License

Forge Proposal Simulator is made available under the MIT License, which disclaims all warranties in relation to the project and which limits the liability of those that contribute and maintain the project. As set out further in the Terms, you acknowledge that you are solely responsible for any use of Forge Proposal Simulator contracts and you assume all risks associated with any such use.
