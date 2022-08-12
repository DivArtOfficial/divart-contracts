// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { PaymentSplitter } from "../src/PaymentSplitter.sol";
import "forge-std/Test.sol";

contract PaymentSplitterTest is Test {
    function testReleaseAll() public {
        address[] memory payees = new address[](2);
        uint256[] memory shares = new uint256[](2);

        payees[0] = address(1);
        payees[1] = address(2);
        shares[0] = 1;
        shares[1] = 2;

        PaymentSplitter paymentSplitter = new PaymentSplitter(payees, shares);

        vm.deal(address(paymentSplitter), 1 ether);
        paymentSplitter.releaseAll();
        assertEq(address(1).balance, uint256(1 ether * 1) / 3);
        assertEq(address(2).balance, uint256(1 ether * 2) / 3);

        vm.deal(address(this), 3 ether);
        (bool success, ) = address(paymentSplitter).call{ value: 3 ether }("");
        assertTrue(success);
        paymentSplitter.releaseAll();
        assertEq(address(1).balance, uint256(4 ether * 1) / 3);
        assertEq(address(2).balance, uint256(4 ether * 2) / 3);
    }
}
