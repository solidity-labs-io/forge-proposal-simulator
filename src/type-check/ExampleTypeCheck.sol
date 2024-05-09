// SPDX-License-Identifier: GPL-3.0

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
