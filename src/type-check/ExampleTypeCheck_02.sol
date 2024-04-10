// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.19;

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
