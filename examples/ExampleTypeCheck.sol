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
        uint256 varA2;
        StructB structB;
    }

    constructor(StructA memory structA, uint256 arg1, uint256 arg2) {}

    function encode(
        StructA memory structA,
        uint256 arg1,
        uint256 arg2
    ) external pure returns (bytes memory) {
        return abi.encode(structA, arg1, arg2);
    }
}
