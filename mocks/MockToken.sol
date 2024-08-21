// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/mocks/MockERC20.sol";

/// @notice This is a mock contract for testing purposes only, it SHOULD NOT be used in production.
contract MockToken is MockERC20 {
    constructor(string memory name, string memory symbol) {
        initialize(name, symbol, 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
