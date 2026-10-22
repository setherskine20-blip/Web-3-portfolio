// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/TokenForge.sol";

contract TokenForgeTest is Test {
    TokenForge token;
    address owner = address(0xA11CE);
    address alice = address(0xA);
    address bob = address(0xB);

    function setUp() public {
        token = new TokenForge("TokenForge", "TFG", 1_000_000e18, owner);
        vm.prank(owner);
        token.transfer(alice, 1000e18);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "TokenForge");
        assertEq(token.symbol(), "TFG");
        assertEq(token.decimals(), 18);
    }

    function test_Transfer() public {
        vm.prank(alice);
        token.transfer(bob, 100e18);
        assertEq(token.balanceOf(bob), 100e18);
        assertEq(token.balanceOf(alice), 900e18);
    }

    function test_ApproveTransferFrom() public {
        vm.prank(alice);
        token.approve(bob, 50e18);
        vm.prank(bob);
        token.transferFrom(alice, bob, 50e18);
        assertEq(token.balanceOf(bob), 50e18);
    }

    function test_MintOnlyOwner() public {
        vm.prank(owner);
        token.mint(alice, 10e18);
        assertEq(token.balanceOf(alice), 1010e18);
        vm.prank(alice);
        vm.expectRevert(TokenForge.NotOwner.selector);
        token.mint(alice, 10e18);
    }

    function test_Pause() public {
        vm.prank(owner);
        token.pause();
        vm.prank(alice);
        vm.expectRevert(TokenForge.PausedErr.selector);
        token.transfer(bob, 1e18);
    }

    function test_Burn() public {
        vm.prank(alice);
        token.burn(100e18);
        assertEq(token.balanceOf(alice), 900e18);
        assertEq(token.totalSupply(), 1_000_000e18 - 100e18);
    }

    function test_Permit() public {
        uint256 pk = 0xBEEF;
        address owner2 = vm.addr(pk);
        vm.prank(owner);
        token.transfer(owner2, 500e18);
        // build permit
        uint256 deadline = block.timestamp + 1 days;
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            owner2, bob, 100e18, token.nonces(owner2), deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        token.permit(owner2, bob, 100e18, deadline, v, r, s);
        assertEq(token.allowance(owner2, bob), 100e18);
    }

    function test_DelegateVotes() public {
        vm.prank(alice);
        token.delegate(bob);
        assertEq(token.getVotes(bob), 1000e18);
    }

    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != alice);
        amount = bound(amount, 0, token.balanceOf(alice));
        uint256 beforeAlice = token.balanceOf(alice);
        uint256 beforeTo = token.balanceOf(to);
        vm.prank(alice);
        token.transfer(to, amount);
        assertEq(token.balanceOf(alice), beforeAlice - amount);
        assertEq(token.balanceOf(to), beforeTo + amount);
    }
}