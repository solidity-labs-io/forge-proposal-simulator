pragma solidity ^0.8.0;

/// @notice This is a mock contract for testing purposes only, it SHOULD NOT be used in production.
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

        highestBidder = msg.sender;
        highestBid = msg.value;

        if (previousBidder != address(0)) {
            (bool success, ) = payable(previousBidder).call{value: msg.value}("");
            assert(success);
        }
    }

    function endAuction() public {
        require(msg.sender == owner, "Only owner can end auction");
        payable(owner).transfer(highestBid);
    }
}
