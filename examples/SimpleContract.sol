pragma solidity 0.8.19;

import {Ownable} from "@utils/Ownable.sol";

contract SimpleContract is Ownable {
    bool public active;

    constructor() Ownable(msg.sender) {}

    function setActive(bool _active) external onlyOwner {
	active = _active;
    }
}

