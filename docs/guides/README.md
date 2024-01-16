# Guides 

FPS is designed to be loosely coupled, making it easy to integrate into any
governance model. Each of these governance models have their unique
specifications. To accommodate the unique requirements of different governance systems, FPS
introduces [proposal-specific](proposals/) contracts. Each contract is designed to align perfectly with the operational nuances of the respective governance model.

## Validated Governance Models

FPS's versatility and robustness have been validated through successful integration with leading governance models. To date, FPS has been tested and confirmed for compatibility with:

1. [Gnosis Safe Multisig](./multisig-proposal.md)
2. [Openzeppelin Timelock Controller](./timelock-proposal.md) 

## Example Contracts

Included here are contracts for use as examples in proposal contracts. It's
important to understand that these are meant solely for demonstration purposes
and are not recommended for production use due to the lack of validation and
audit processes. Their main function is to demonstrate the deployment process
and the setup of protocol parameters within proposals. For a practical
application, it is advised to copy these contracts into your project and follow
the guides linked in the section above.

### Vault contract
```solidity
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { Pausable } from "@openzeppelin/security/Pausable.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract Vault is Ownable, Pausable {
    uint256 public LOCK_PERIOD = 1 weeks;

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => mapping(address => Deposit)) public deposits;
    mapping(address => bool) public tokenWhitelist;

    constructor() Ownable() Pausable() {}

    function whitelistToken(address token, bool active) external onlyOwner {
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

    function withdraw(
        address token,
        address payable to,
        uint256 amount
    ) external whenNotPaused {
        require(tokenWhitelist[token], "Vault: token must be active");
        require(amount > 0, "Vault: amount must be greater than 0");
        require(token != address(0), "Vault: token must not be 0x0");
        require(
            deposits[token][msg.sender].amount >= amount,
            "Vault: insufficient balance"
        );
        require(
            deposits[token][msg.sender].timestamp + LOCK_PERIOD <
                block.timestamp,
            "Vault: lock period has not passed"
        );

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
```


### MockToken contract

```solidity
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract MockToken is ERC20, Ownable {
    constructor() ERC20("MockToken", "MTK") Ownable() {
        uint256 supply = 10_000_000e18;
        _mint(msg.sender, supply);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

```

