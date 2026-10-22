// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IPriceOracle {
    function getPrice() external view returns (uint256);
}

/// @title LendingPool
/// @notice Collateralized lending pool (Aave/Compound style). Contains intentional vulnerabilities.
contract LendingPool {
    IERC20 public immutable collateralToken; // WETH
    IERC20 public immutable borrowToken;     // USDC
    IPriceOracle public oracle;

    uint256 public constant LTV = 7500;          // 75%
    uint256 public constant LIQUIDATION_THRESHOLD = 8000; // 80%
    uint256 public constant LIQUIDATION_BONUS = 10500;   // 5%
    uint256 public constant BPS = 10_000;
    uint256 public constant RESERVE_FACTOR = 1000;       // 10%

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public reserveBalance;

    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 lastAccrual;
    }
    mapping(address => Position) public positions;

    // Reentrancy guard (manual)
    uint256 private _locked;
    modifier nonReentrant() {
        require(_locked == 0, "reentrant");
        _locked = 1;
        _;
        _locked = 0;
    }

    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed user, uint256 debt, uint256 seized);

    constructor(address _collateral, address _borrow, address _oracle) {
        collateralToken = IERC20(_collateral);
        borrowToken = IERC20(_borrow);
        oracle = IPriceOracle(_oracle);
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "zero");
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "transferFrom");
        positions[msg.sender].collateral += amount;
        totalDeposits += amount;
        emit Deposit(msg.sender, amount);
    }

    /// @notice VULNERABLE (H-01): external call before state update despite nonReentrant (CEI violated).
    function withdraw(uint256 amount) external nonReentrant {
        Position storage p = positions[msg.sender];
        require(p.collateral >= amount, "insufficient collateral");
        require(p.debt == 0, "outstanding debt");
        // BUG: state update AFTER external transfer
        require(collateralToken.transfer(msg.sender, amount), "transfer");
        p.collateral -= amount;            // state update after external call
        totalDeposits -= amount;
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        Position storage p = positions[msg.sender];
        uint256 price = oracle.getPrice();
        // BUG (M-01): precision loss — divides before multiplying
        uint256 collateralValue = (p.collateral * price) / 1e18 / 1e12; // to 6 decimals
        uint256 maxBorrow = (collateralValue * LTV) / BPS;
        require(p.debt + amount <= maxBorrow, "insufficient collateral");
        // BUG (L-01): no interest accrual
        p.debt += amount;
        totalBorrows += amount;
        require(borrowToken.transfer(msg.sender, amount), "transfer");
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external nonReentrant {
        Position storage p = positions[msg.sender];
        require(borrowToken.transferFrom(msg.sender, address(this), amount), "transferFrom");
        if (amount > p.debt) amount = p.debt;
        p.debt -= amount;
        totalBorrows -= amount;
        emit Repay(msg.sender, amount);
    }

    /// @notice VULNERABLE (H-02): liquidator seizes collateral without repaying debt; no close factor.
    function liquidate(address user, uint256 repayAmount) external nonReentrant {
        Position storage p = positions[user];
        uint256 price = oracle.getPrice();
        uint256 collateralValue = (p.collateral * price) / 1e18 / 1e12;
        uint256 maxBorrow = (collateralValue * LIQUIDATION_THRESHOLD) / BPS;
        require(p.debt > maxBorrow, "not liquidatable");
        // BUG: seizes ALL collateral regardless of repayAmount
        uint256 seized = p.collateral;
        p.collateral = 0;
        p.debt = 0; // debt zeroed without repayment
        require(collateralToken.transfer(msg.sender, seized), "transfer");
        emit Liquidate(msg.sender, user, repayAmount, seized);
    }

    /// @notice VULNERABLE (H-03): admin can set arbitrary oracle with no timelock/multisig.
    function setOracle(address _oracle) external {
        // BUG: no access control
        oracle = IPriceOracle(_oracle);
    }

    function healthFactor(address user) external view returns (uint256) {
        Position memory p = positions[user];
        if (p.debt == 0) return type(uint256).max;
        uint256 price = oracle.getPrice();
        uint256 collateralValue = (p.collateral * price) / 1e18 / 1e12;
        return (collateralValue * LIQUIDATION_THRESHOLD) / p.debt;
    }
}