// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

error NotEnoughWhitelistSpots();

contract Whitelistable {
    event WhitelistSpotsAdded(address indexed addr, uint256 amount);
    event WhitelistSpotsRemoved(address indexed addr, uint256 amount);

    mapping(address => uint256) public whitelistSpots;

    modifier onlyWhitelisted() {
        if (whitelistSpots[msg.sender] == 0) {
            revert NotEnoughWhitelistSpots();
        }

        _;
    }

    function _addWhitelistSpots(address _addr, uint256 _amount) internal {
        whitelistSpots[_addr] += _amount;
        emit WhitelistSpotsAdded(_addr, _amount);
    }

    function _removeWhitelistSpots(address _addr, uint256 _amount) internal {
        if (whitelistSpots[_addr] < _amount) {
            revert NotEnoughWhitelistSpots();
        }

        whitelistSpots[_addr] -= _amount;
        emit WhitelistSpotsRemoved(_addr, _amount);
    }

    function _clearWhitelistSpots(address _addr) internal {
        uint256 amount = whitelistSpots[_addr];
        _removeWhitelistSpots(_addr, amount);
    }
}
