// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import "../src/ExclusiveWhitelistable.sol";
import "forge-std/Test.sol";

contract ExclusiveWhitelistableTest is Test, ExclusiveWhitelistable {
    function testAddExclusiveWhitelistSpots() public {
        _addExclusiveWhitelistSpots(msg.sender, 1);
        assertEq(exclusiveWhitelistSpots[msg.sender], 1);
    }

    function testRemoveExclusiveWhitelistSpots() public {
        _addExclusiveWhitelistSpots(msg.sender, 1);
        vm.expectRevert(NotEnoughExclusiveWhitelistSpots.selector);
        _removeExclusiveWhitelistSpots(msg.sender, 5);
        _removeExclusiveWhitelistSpots(msg.sender, 1);
        assertEq(exclusiveWhitelistSpots[msg.sender], 0);
    }

    function testClearExclusiveWhitelistSpots() public {
        _addExclusiveWhitelistSpots(msg.sender, 123);
        _clearExclusiveWhitelistSpots(msg.sender);
        assertEq(exclusiveWhitelistSpots[msg.sender], 0);
    }

    function _exclusiveWhitelistOnlyFunction() private onlyExclusiveWhitelisted {}

    function testExclusiveWhitelistOnlyModifier() public {
        vm.expectRevert(NotEnoughExclusiveWhitelistSpots.selector);
        _exclusiveWhitelistOnlyFunction();
        _addExclusiveWhitelistSpots(address(this), 42);
        _exclusiveWhitelistOnlyFunction();
    }
}
