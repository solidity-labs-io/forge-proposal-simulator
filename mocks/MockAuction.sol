pragma solidity ^0.8.0;

contract MockAuction {
    address public highestBidder;
    uint public highestBid;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function bid() public payable {
        require(msg.value > highestBid, "Bid not high enough");
        address previousBidder = highestBidder;
        uint256 previousBid = highestBid;

        highestBidder = msg.sender;
        highestBid = msg.value;

        if (previousBidder != address(0)) {
            payable(previousBidder).transfer(previousBid);
        }
    }

    function endAuction() public {
        require(msg.sender == owner, "Only owner can end auction");
        payable(owner).transfer(highestBid);
    }
}
