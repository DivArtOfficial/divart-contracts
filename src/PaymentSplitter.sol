// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

import { PaymentSplitter as Splitter } from "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract PaymentSplitter is Splitter {
    uint256 _payeesCount;

    constructor(address[] memory payees_, uint256[] memory shares_) Splitter(payees_, shares_) {
        _payeesCount = payees_.length;
    }

    function releaseAll() public {
        for (uint256 i = 0; i < _payeesCount; i++) {
            address payee = super.payee(i);
            super.release(payable(payee));
        }
    }
}
