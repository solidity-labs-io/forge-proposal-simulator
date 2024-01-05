pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {Pausable} from "@openzeppelin/security/Pausable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract Vault is Ownable, Pausable {
    uint256 public LOCK_PERIOD = 1 weeks;

    struct Deposit {
	uint256 amount;
	uint256 timestamp;
    }

    mapping(address=> mapping (address => Deposit )) public deposits;
    mapping(address=> bool ) public tokenWhitelist;

    constructor() Ownable() Pausable() {
    }

    function setToken(address token, bool active) external onlyOwner {
	tokenWhitelist[token] = active;
    }

    function deposit(address token, uint256 amount) external whenNotPaused {
	require(tokenWhitelist[token], "Vault: token must be active");
	require(amount > 0, "Vault: amount must be greater than 0");
	require(token != address(0), "Vault: token must not be 0x0");

	Deposit storage userDeposit = deposits[token][msg.sender];
	userDeposit.amount += amount;
	userDeposit.timestamp = block.timestamp;

	IERC20(token).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address token, address payable to, uint256 amount) external whenNotPaused {
	require(tokenWhitelist[token], "Vault: token must be active");
	require(amount > 0, "Vault: amount must be greater than 0");
	require(token != address(0), "Vault: token must not be 0x0");
	require(deposits[token][msg.sender].amount >= amount, "Vault: insufficient balance");
	require(deposits[token][msg.sender].timestamp + LOCK_PERIOD < block.timestamp, "Vault: lock period has not passed");

	Deposit storage userDeposit = deposits[token][msg.sender];
	userDeposit.amount -= amount;

	IERC20(token).transfer(to, amount);
    }

    function pause() external onlyOwner {
	_pause();
    }

    function unpause() external onlyOwner {
	_unpause();
    }
}

