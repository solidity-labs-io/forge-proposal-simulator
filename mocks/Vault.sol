pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract Vault {
    uint256 public LOCK_PERIOD = 1 weeks;

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address _token => mapping(address _user => Deposit _deposit))
        public deposits;
    mapping(address _token => bool _isWhitelisted) public tokenWhitelist;

    constructor() Pausable() {}

    function whitelistToken(address token, bool active) external {
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
}
