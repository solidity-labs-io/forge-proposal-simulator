pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract SimpleContract is Ownable {
    bool public active;

    constructor() Ownable() {}

    function setActive(bool _active) external onlyOwner {
	active = _active;
    }
}

