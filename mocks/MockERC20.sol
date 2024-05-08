pragma solidity ^0.8.0;

import {IERC20} from "./IERC20.sol";

/// @notice This is a mock contract of the ERC20 standard for testing purposes only, it SHOULD NOT be used in production.
/// @dev Forked from: https://github.com/transmissions11/solmate/blob/0384dbaaa4fcb5715738a9254a7c0a4cb62cf458/src/tokens/ERC20.sol
contract MockERC20 is IERC20 {
    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string internal _name;

    string internal _symbol;

    uint8 internal _decimals;

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal _totalSupply;

    mapping(address owner => uint256 balance) internal _balanceOf;

    mapping(address owner => mapping(address spender => uint256 balance))
        internal _allowance;

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) external view override returns (uint256) {
        return _balanceOf[owner];
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowance[owner][spender];
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZE
    //////////////////////////////////////////////////////////////*/

    /// @dev A bool to track whether the contract has been initialized.
    bool private initialized;

    /// @dev To hide constructor warnings across solc versions due to different constructor visibility requirements and
    /// syntaxes, we add an initialization function that can be called only once.
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public {
        require(!initialized, "ALREADY_INITIALIZED");

        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _balanceOf[msg.sender] = _sub(_balanceOf[msg.sender], amount);
        _balanceOf[to] = _add(_balanceOf[to], amount);

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 allowed = _allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != ~uint256(0))
            _allowance[from][msg.sender] = _sub(allowed, amount);

        _balanceOf[from] = _sub(_balanceOf[from], amount);
        _balanceOf[to] = _add(_balanceOf[to], amount);

        emit Transfer(from, to, amount);

        return true;
    }

    function _mint(address to, uint256 amount) internal {
        _totalSupply = _add(_totalSupply, amount);
        _balanceOf[to] = _add(_balanceOf[to], amount);

        emit Transfer(address(0), to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MATH LOGIC
    //////////////////////////////////////////////////////////////*/

    function _add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "ERC20: addition overflow");
        return c;
    }

    function _sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(a >= b, "ERC20: subtraction underflow");
        return a - b;
    }
}
