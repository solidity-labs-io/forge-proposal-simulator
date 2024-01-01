pragma solidity 0.8.19;

contract SimpleContract {
    bool public deployed;

    function setDeployed(bool _deployed) external {
	deployed = _deployed;
    }
}

