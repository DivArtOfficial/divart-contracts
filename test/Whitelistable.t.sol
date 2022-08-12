// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import "../src/Whitelistable.sol";
import "forge-std/Test.sol";

contract WhitelistableTest is Test, Whitelistable {
    function testAddWhitelistSpots() public {
        _addWhitelistSpots(msg.sender, 1);
        assertEq(whitelistSpots[msg.sender], 1);
    }

    function testRemoveWhitelistSpots() public {
        _addWhitelistSpots(msg.sender, 1);
        vm.expectRevert(NotEnoughWhitelistSpots.selector);
        _removeWhitelistSpots(msg.sender, 5);
        _removeWhitelistSpots(msg.sender, 1);
        assertEq(whitelistSpots[msg.sender], 0);
    }

    function testClearWhitelistSpots() public {
        _addWhitelistSpots(msg.sender, 123);
        _clearWhitelistSpots(msg.sender);
        assertEq(whitelistSpots[msg.sender], 0);
    }

    function _whitelistOnlyFunction() private onlyWhitelisted {}

    function testWhitelistOnlyModifier() public {
        vm.expectRevert(NotEnoughWhitelistSpots.selector);
        _whitelistOnlyFunction();
        _addWhitelistSpots(address(this), 42);
        _whitelistOnlyFunction();
    }
}
