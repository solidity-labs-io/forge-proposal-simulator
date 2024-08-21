pragma solidity ^0.8.0;

/// @notice This is a mock contract for testing purposes only, it SHOULD NOT be used in production.
contract MockSavingContract {
    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address user => Deposit[] deposits) public deposits;

    function deposit(uint256 lockTime) public payable {
        require(msg.value > 0, "Must send some Ether");
        deposits[msg.sender].push(
            Deposit({amount: msg.value, unlockTime: block.timestamp + lockTime})
        );
    }

    function withdraw(uint256 depositIndex) public {
        Deposit memory userDeposit = deposits[msg.sender][depositIndex];
        require(
            block.timestamp >= userDeposit.unlockTime,
            "Deposit is still locked"
        );
        require(userDeposit.amount > 0, "No funds to withdraw");

        uint256 amount = userDeposit.amount;
        deposits[msg.sender][depositIndex].amount = 0;
        payable(msg.sender).transfer(amount);
    }

    function getDeposit(
        address user,
        uint256 depositIndex
    ) public view returns (uint256 amount, uint256 unlockTime) {
        return (
            deposits[user][depositIndex].amount,
            deposits[user][depositIndex].unlockTime
        );
    }
}
