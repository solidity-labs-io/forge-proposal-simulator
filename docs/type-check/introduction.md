# Type Checking

Type checking enables the validation of deployed bytecode against local artifacts, ensuring accuracy. This facilitates a team of developers to verify each other's deployments with the type checking script. A developer can intiate verification of his team member's bytecode by deploying the contract locally through Foundry, then compare their generated bytecode with the already on-chain version. He can use it to verify his own deployements as well. By leveraging type checking, a team of developers can efficiently validate contracts, enhancing transparency and security in their Solidity smart contract development workflows.

Let's explore a hypothetical scenario where a team is going to deploy to Ethereum mainnet. One developer deploys an old version of contracts because he forgot to pull the latest contracts. The older version that he has deployed has a critical bug in a single line of code. Other team members go to etherscan to verify the source code looks correct, however, they might miss checking whether the latest bug fix is deployed or not. Instead, if they use the type checking script they will be able to verify the deployment automatically without having to look at and compare each and every line of code.

## Setting Up

### Step 1: Add Dependency

Add `forge-proposal-simulator` to your project using Forge:

```sh
forge install https://github.com/solidity-labs-io/forge-proposal-simulator.git
```

### Step 2: Remapping

Update your `remappings.txt` to include:

```sh
echo @forge-proposal-simulator=lib/forge-proposal-simulator/ >> remappings.txt
```

### Step 3: Addresses File

Create a JSON file following the structure defined in [Addresses](../overview/architecture/addresses.md). Keeping the addresses file in a separate folder for example `./addresses/addresses.json` is recommended. Add all contracts to `Addresses.json`.

### Step 4: TypeCheckAddresses File

Create a `TypeCheckAddresses.json` file following the instructions provided in [type-check.md](./type-check.md).

### Step 5: Install npm packages

Enter the `lib/forge-proposal-simulator/typescript` directory and install npm packages.

```bash
cd lib/forge-proposal-simulator/typescript && npm i
```

Change the directory again to the root repo.

```bash
cd ../../../
```

### Step 6: Add Environment Variables

Add the below environment variables to `.env`.

```
ADDRESSES_PATH                # Path to addresses.json file
TYPE_CHECK_ADDRESSES_PATH     # Path to typeCheckAddresses.json file
```

Example:

```
TYPE_CHECK_ADDRESSES_PATH=addresses/TypeCheckAddresses.json
ADDRESSES_PATH=addresses/Addresses.json
```

### Step 7: File Read Access

Make sure to allow read access to `Addresses.json`, `TypeCheckAddresses.json`, and the `artifact` folder inside of `foundry.toml`.

```toml
[profile.default]

fs_permissions = [{ access = "read", path = "./"}]
```
