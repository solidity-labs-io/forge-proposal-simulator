pragma solidity ^0.8.0;

import {MockERC20} from "./MockERC20.sol";

contract Token is MockERC20 {
    constructor() {
        initialize("MockToken", "MTK", 18);
        uint256 supply = 10_000_000e18;
        _mint(msg.sender, supply);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
