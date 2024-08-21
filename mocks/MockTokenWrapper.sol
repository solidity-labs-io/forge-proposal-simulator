// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockToken} from "mocks/MockToken.sol";

/// @notice This is a mock contract for testing purposes only, it SHOULD NOT be used in production.
contract MockTokenWrapper {
    address internal _tokenAddress;

    constructor(address tokenAddress) {
        _tokenAddress = tokenAddress;
    }

    function mint() external payable {
        MockToken(_tokenAddress).transfer(msg.sender, msg.value);
    }

    function redeemTokens(uint256 tokenAmount) external {
        require(
            MockToken(_tokenAddress).balanceOf(msg.sender) >= tokenAmount,
            "Insufficient token balance"
        );

        require(
            address(this).balance >= tokenAmount,
            "Insufficient ETH balance in contract"
        );

        MockToken(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );
        payable(msg.sender).transfer(tokenAmount);
    }
}
