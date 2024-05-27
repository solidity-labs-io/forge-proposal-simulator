# Type check Addresses

## Overview

The `TypeCheckAddresses.json` file is a JSON file used for verifying the bytecode of already deployed contracts on any chain. This file contains a list of objects, where each object stores the `name`, `constructorArgs`, and `artifactPath` for all the contracts that we want to type check. The `name` should be the same as the `name` in `Addresses.json` as it links both JSONs together. The `constructorArgs` should be in comma-separated array format. For `Address`, `bytes`, and `string`, double quotes should be used. Tuples, on the other hand, are passed like arrays `[]`. Additionally, each `"` in JSON is escaped using `\` since it is a special character in the JSON file.

## Structure

ExampleTypeCheck.sol

```solidity
pragma solidity ^0.8.0;

contract ExampleTypeCheck {
    struct StructC {
        string varC1;
        uint256 varC2;
    }

    struct StructB {
        bytes varB1;
        uint256 varB2;
        StructC structC;
    }
    struct StructA {
        address varA1;
        bytes32 varA2;
        StructB structB;
    }

    constructor(
        StructA memory structA,
        string[] memory arg1,
        uint256[] memory arg2,
        StructB[] memory structb
    ) {}

    function encode(
        StructA memory structA,
        string[] memory arg1,
        uint256[] memory arg2,
        StructB[] memory structb
    ) external pure returns (bytes memory) {
        return abi.encode(structA, arg1, arg2, structb);
    }
}
```

ExampleTypeCheck_02.sol

```solidity
pragma solidity ^0.8.0;

contract ExampleTypeCheck_02 {
    struct StructA {
        uint256[] varA1;
    }

    struct StructB {
        StructA[] varB1;
    }

    constructor(
        uint256[][] memory,
        StructA[] memory,
        StructB[] memory,
        address[][] memory
    ) {}
}
```

TypeCheckAddresses.json for above two contract.

```json
[
    {
        "name": "ExampleTypeCheck",
        "constructorArgs": "[[\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", \"0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5000000000000000000000000\", [\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", 2, [\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", 2]]], [\"Arg1\", \"Arg2\"], [2, 3], [[\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", 2, [\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", 2]], [\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", 2, [\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\", 2]]]]",
        "artifactPath": "out/ExampleTypeCheck.sol/ExampleTypeCheck.json"
    },
    {
        "name": "ExampleTypeCheck_02",
        "constructorArgs": "[[[1, 2], [3, 4]], [[[1, 2]], [[3, 4]]], [[[[[1, 2]], [[3, 4]]]], [[[[5, 6]], [[7, 8]]]]], [[\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\"], [\"0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5\"]]]",
        "artifactPath": "out/ExampleTypeCheck_02.sol/ExampleTypeCheck_02.json"
    }
]
```
