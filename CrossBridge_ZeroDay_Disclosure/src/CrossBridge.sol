// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

/// @title CrossBridge
/// @notice Cross-chain bridge with validator signature vouchers. CRITICAL vulnerability: nonce not consumed.
contract CrossBridge {
    IERC20 public immutable token;
    address public immutable validator;
    uint256 public chainId;

    // Missing: mapping(uint256 => bool) public usedNonces;
    // Missing: mapping(bytes32 => bool) public usedMessages;

    event Deposited(address indexed from, uint256 amount, uint256 nonce, uint256 dstChainId);
    event Withdrawn(address indexed to, uint256 amount, uint256 nonce, uint256 srcChainId);

    constructor(address _token, address _validator) {
        token = IERC20(_token);
        validator = _validator;
        chainId = block.chainid;
    }

    /// @notice Lock tokens on source chain.
    function deposit(uint256 amount, uint256 dstChainId) external {
        require(token.transfer(address(this), amount), "transfer");
        emit Deposited(msg.sender, amount, block.timestamp, dstChainId);
    }

    /// @notice Verify EIP-712-style signature over voucher.
    function _verify(address to, uint256 amount, uint256 nonce, uint256 srcChainId, bytes memory sig) internal view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(to, amount, nonce, srcChainId, address(this)));
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", structHash));
        (bytes32 r, bytes32 s, uint8 v) = _split(sig);
        return ecrecover(digest, v, r, s) == validator;
    }

    function _split(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "bad sig");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /// @notice Withdraw on destination chain using validator voucher.
    /// @dev CRITICAL (H-01): nonce not recorded as consumed -> unlimited replay.
    /// @dev CRITICAL (H-02): chainId check missing in verifier -> cross-chain replay.
    function withdraw(address to, uint256 amount, uint256 nonce, uint256 srcChainId, bytes memory sig) external {
        require(_verify(to, amount, nonce, srcChainId, sig), "invalid sig");
        token.mint(to, amount);
        emit Withdrawn(to, amount, nonce, srcChainId);
    }

    /// @notice Batch withdraw (amplifies replay).
    function batchWithdraw(address[] calldata tos, uint256[] calldata amounts, uint256[] calldata nonces, bytes[] calldata sigs) external {
        for (uint256 i = 0; i < tos.length; i++) {
            this.withdraw(tos[i], amounts[i], nonces[i], 0, sigs[i]);
        }
    }
}