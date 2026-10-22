// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title YieldMaxVault
/// @notice ERC-4626 vault with performance fee, high-water mark, and strategy hook.
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IStrategy {
    function deposit(uint256 assets) external;
    function withdraw(uint256 assets) external returns (uint256);
    function totalAssets() external view returns (uint256);
}

contract YieldMaxVault {
    IERC20 public immutable asset;
    IStrategy public strategy;

    string public name = "YieldMax Vault Share";
    string public symbol = "ymV";
    uint8 public constant decimals = 18;

    uint256 public totalShares;
    mapping(address => uint256) public balanceOf;
    uint256 public totalAssets; // tracked (cash + strategy)
    uint256 public highWaterMark;
    uint256 public performanceFeeBps = 1000; // 10%
    address public feeRecipient;
    uint256 public lastAccrual;
    uint256 public managementFeeBps = 200; // 2% annual

    bool public paused;
    address public owner;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Harvest(uint256 profit, uint256 fee);
    event StrategyUpdated(address strategy);

    error Paused();
    error ZeroAmount();
    error InsufficientShares();
    error NotOwner();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier whenNotPaused() { if (paused) revert Paused(); _; }

    constructor(address _asset, address _feeRecipient, address _owner) {
        asset = IERC20(_asset);
        feeRecipient = _feeRecipient;
        owner = _owner;
        lastAccrual = block.timestamp;
    }

    function _accrueManagementFee() internal {
        uint256 elapsed = block.timestamp - lastAccrual;
        if (elapsed == 0) return;
        uint256 fee = (totalAssets * managementFeeBps * elapsed) / (BPS * 365 days);
        if (fee > 0 && totalShares > 0) {
            // mint fee shares to feeRecipient
            uint256 feeShares = (fee * totalShares) / (totalAssets - fee + 1);
            totalShares += feeShares;
            balanceOf[feeRecipient] += feeShares;
            totalAssets += fee;
        }
        lastAccrual = block.timestamp;
    }

    uint256 public constant BPS = 10_000;

    function setStrategy(address s) external onlyOwner {
        if (address(strategy) != address(0)) {
            // withdraw all from old strategy
            uint256 bal = strategy.totalAssets();
            if (bal > 0) strategy.withdraw(bal);
        }
        strategy = IStrategy(s);
        if (s != address(0)) {
            uint256 cash = asset.balanceOf(address(this));
            if (cash > 0) { asset.approve(s, cash); strategy.deposit(cash); }
        }
        emit StrategyUpdated(s);
    }

    function totalManagedAssets() public view returns (uint256) {
        uint256 strat = address(strategy) == address(0) ? 0 : strategy.totalAssets();
        return asset.balanceOf(address(this)) + strat;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 ts = totalShares;
        uint256 ta = totalAssets == 0 ? totalManagedAssets() : totalAssets;
        if (ts == 0 || ta == 0) return assets;
        return (assets * ts) / ta;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalShares == 0) return 0;
        uint256 ta = totalAssets == 0 ? totalManagedAssets() : totalAssets;
        return (shares * ta) / totalShares;
    }

    function deposit(uint256 assets, address receiver) external whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        _accrueManagementFee();
        // sync totalAssets with reality
        totalAssets = totalManagedAssets();
        shares = convertToShares(assets);
        if (shares == 0) shares = 1;
        require(asset.transferFrom(msg.sender, address(this), assets), "transferFrom");
        if (address(strategy) != address(0)) {
            asset.approve(address(strategy), assets);
            strategy.deposit(assets);
        }
        totalShares += shares;
        balanceOf[receiver] += shares;
        totalAssets = totalManagedAssets();
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner_) external whenNotPaused returns (uint256 shares) {
        if (assets == 0) revert ZeroAmount();
        _accrueManagementFee();
        totalAssets = totalManagedAssets();
        shares = convertToShares(assets);
        if (shares > balanceOf[owner_]) revert InsufficientShares();
        if (msg.sender != owner_) revert NotOwner();
        balanceOf[owner_] -= shares;
        totalShares -= shares;
        // withdraw from strategy if needed
        uint256 cash = asset.balanceOf(address(this));
        if (cash < assets && address(strategy) != address(0)) {
            uint256 need = assets - cash;
            strategy.withdraw(need);
        }
        require(asset.transfer(receiver, assets), "transfer");
        totalAssets = totalManagedAssets();
        emit Withdraw(msg.sender, receiver, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner_) external whenNotPaused returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (shares > balanceOf[owner_]) revert InsufficientShares();
        if (msg.sender != owner_) revert NotOwner();
        _accrueManagementFee();
        totalAssets = totalManagedAssets();
        assets = convertToAssets(shares);
        balanceOf[owner_] -= shares;
        totalShares -= shares;
        uint256 cash = asset.balanceOf(address(this));
        if (cash < assets && address(strategy) != address(0)) {
            strategy.withdraw(assets - cash);
        }
        require(asset.transfer(receiver, assets), "transfer");
        totalAssets = totalManagedAssets();
    }

    function harvest() external onlyOwner {
        _accrueManagementFee();
        totalAssets = totalManagedAssets();
        if (totalAssets <= highWaterMark) { highWaterMark = totalAssets > highWaterMark ? totalAssets : highWaterMark; return; }
        uint256 profit = totalAssets - highWaterMark;
        uint256 fee = (profit * performanceFeeBps) / BPS;
        if (fee > 0) {
            uint256 feeShares = convertToShares(fee);
            if (feeShares == 0) feeShares = 1;
            totalShares += feeShares;
            balanceOf[feeRecipient] += feeShares;
            totalAssets = totalManagedAssets();
        }
        highWaterMark = totalAssets;
        emit Harvest(profit, fee);
    }

    function pause() external onlyOwner { paused = true; }
    function unpause() external onlyOwner { paused = false; }
}