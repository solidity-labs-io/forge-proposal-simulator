// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20, ERC20Permit, ERC20VotesComp} from "openzeppelin/token/ERC20/extensions/ERC20VotesComp.sol";

contract MockERC20Votes is ERC20VotesComp {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20Permit(name_) ERC20(name_, symbol_) {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}
