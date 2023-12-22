contract Mock {
    bool public deployed;

    function setDeployed(bool _deployed) external {
	deployed = _deployed;
    }
}

