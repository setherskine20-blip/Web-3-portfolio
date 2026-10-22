// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TokenForge
/// @notice Production ERC-20: Permit (EIP-2612), Votes (ERC20Votes), Pausable, Ownable, Burnable.
import {IERC20} from "./IERC20.sol";

// Minimal inline implementations to avoid external deps.

contract TokenForge {
    // --- ERC20 core ---
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // --- Permit (EIP-2612) ---
    bytes32 public immutable DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // --- Votes (ERC20Votes simplified) ---
    mapping(address => address) public delegates;
    mapping(address => uint256) public votingPower; // 1 token = 1 vote (no delegation multiplier for simplicity)
    uint256 public totalVotes;

    // --- Access / pause ---
    address public owner;
    bool public paused;

    // --- Events ---
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);
    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);
    event Paused(address account);
    event Unpaused(address account);

    // --- Errors ---
    error NotOwner();
    error PausedErr();
    error ZeroAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error PermitExpired();
    error InvalidSignature();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier whenNotPaused() { if (paused) revert PausedErr(); _; }

    constructor(string memory _name, string memory _symbol, uint256 initialSupply, address _owner) {
        if (_owner == address(0)) revert ZeroAddress();
        name = _name; symbol = _symbol; owner = _owner;
        uint256 chainId;
        assembly { chainId := chainid() }
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(_name)), keccak256("1"), chainId, address(this)
        ));
        _mint(_owner, initialSupply);
    }

    // --- ERC20 ---
    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (balanceOf[from] < amount) revert InsufficientBalance();
        // update votes
        _moveVotingPower(delegates[from] == address(0) ? from : delegates[from],
                         delegates[to] == address(0) ? to : delegates[to], amount, from, to);
        unchecked { balanceOf[from] -= amount; balanceOf[to] += amount; }
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += amount;
        balanceOf[to] += amount;
        address del = delegates[to] == address(0) ? to : delegates[to];
        _changeVotingPower(del, votingPower[del], votingPower[del] + amount);
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (balanceOf[from] < amount) revert InsufficientBalance();
        address del = delegates[from] == address(0) ? from : delegates[from];
        _changeVotingPower(del, votingPower[del], votingPower[del] - amount);
        unchecked { balanceOf[from] -= amount; totalSupply -= amount; }
        emit Transfer(from, address(0), amount);
    }

    // --- Mint/Burn/Pause ---
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused { _mint(to, amount); }
    function burn(uint256 amount) external whenNotPaused { _burn(msg.sender, amount); }
    function burnFrom(address from, uint256 amount) external whenNotPaused {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert InsufficientAllowance();
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        _burn(from, amount);
    }
    function pause() external onlyOwner { paused = true; emit Paused(msg.sender); }
    function unpause() external onlyOwner { paused = false; emit Unpaused(msg.sender); }
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    // --- Permit ---
    function permit(address owner_, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        if (block.timestamp > deadline) revert PermitExpired();
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01", DOMAIN_SEPARATOR,
            keccak256(abi.encode(_PERMIT_TYPEHASH, owner_, spender, value, nonces[owner_]++, deadline))
        ));
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0) || recovered != owner_) revert InvalidSignature();
        allowance[owner_][spender] = value;
        emit Approval(owner_, spender, value);
    }

    // --- Votes ---
    function delegate(address delegatee) external {
        address current = delegates[msg.sender];
        if (current == address(0)) current = msg.sender;
        delegates[msg.sender] = delegatee;
        if (delegatee == address(0)) delegatee = msg.sender;
        _changeVotingPower(current, votingPower[current], votingPower[current] - balanceOf[msg.sender]);
        _changeVotingPower(delegatee, votingPower[delegatee], votingPower[delegatee] + balanceOf[msg.sender]);
        emit DelegateChanged(msg.sender, current, delegatee);
    }

    function getVotes(address account) external view returns (uint256) { return votingPower[account]; }

    function _changeVotingPower(address delegate, uint256 prev, uint256 next) internal {
        emit DelegateVotesChanged(delegate, prev, next);
        votingPower[delegate] = next;
    }

    function _moveVotingPower(address fromDel, address toDel, uint256 amount, address from, address to) internal {
        if (fromDel == toDel) return;
        _changeVotingPower(fromDel, votingPower[fromDel], votingPower[fromDel] - amount);
        _changeVotingPower(toDel, votingPower[toDel], votingPower[toDel] + amount);
    }
}