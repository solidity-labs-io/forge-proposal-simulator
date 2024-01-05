pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    constructor() ERC20("MockToken", "MTK") Ownable() {
        uint256 supply = 10_000_000e18;
        _mint(msg.sender, supply);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
