// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import "forge-std/Script.sol";
import "../src/type-check/ExampleTypeCheck.sol";

contract DeployExampleTypeCheck is Script {
    function run() external {
        vm.startBroadcast();

        ExampleTypeCheck.StructC memory structC = ExampleTypeCheck.StructC({
            varC1: "0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            varC2: 2
        });

        ExampleTypeCheck.StructB memory structB = ExampleTypeCheck.StructB({
            varB1: hex"95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            varB2: 2,
            structC: structC
        });

        ExampleTypeCheck.StructA memory structA = ExampleTypeCheck.StructA({
            varA1: 0x95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5,
            varA2: hex"95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            structB: structB
        });

        string[] memory stringArg = new string[](2);
        stringArg[0] = "Arg1";
        stringArg[1] = "Arg2";

        uint256[] memory uintArg = new uint256[](2);
        uintArg[0] = 2;
        uintArg[1] = 3;

        ExampleTypeCheck.StructB[]
            memory structBArrayArg = new ExampleTypeCheck.StructB[](2);

        structBArrayArg[0] = ExampleTypeCheck.StructB({
            varB1: hex"95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            varB2: 2,
            structC: structC
        });

        structBArrayArg[1] = ExampleTypeCheck.StructB({
            varB1: hex"95222290DD7278Aa3Ddd389Cc1E1d165CC4BAfe5",
            varB2: 2,
            structC: structC
        });

        ExampleTypeCheck exampleTypeCheck = new ExampleTypeCheck(
            structA,
            stringArg,
            uintArg,
            structBArrayArg
        );

        vm.stopBroadcast();
    }
}
