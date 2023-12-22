contract Mock2 {
    Mock public mock1;
    Mock public mock2;

    constructor(address mock1, address mock2) {
	mock1 = Mock(mock1);
	mock2 = Mock(mock2);
    }

    function setDeployed(address mockAddress, bool deployed) external {
	Mock(mockAddress).setDeployed(deployed);
    }
}
