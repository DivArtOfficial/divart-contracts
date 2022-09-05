// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.14;

error NotEnoughExclusiveWhitelistSpots();

contract ExclusiveWhitelistable {
    event ExclusiveWhitelistSpotsAdded(address indexed addr, uint256 amount);
    event ExclusiveWhitelistSpotsRemoved(address indexed addr, uint256 amount);

    mapping(address => uint256) public exclusiveWhitelistSpots;

    modifier onlyExclusiveWhitelisted() {
        if (exclusiveWhitelistSpots[msg.sender] == 0) {
            revert NotEnoughExclusiveWhitelistSpots();
        }

        _;
    }

    function _addExclusiveWhitelistSpots(address _addr, uint256 _amount) internal {
        exclusiveWhitelistSpots[_addr] += _amount;
        emit ExclusiveWhitelistSpotsAdded(_addr, _amount);
    }

    function _removeExclusiveWhitelistSpots(address _addr, uint256 _amount) internal {
        if (exclusiveWhitelistSpots[_addr] < _amount) {
            revert NotEnoughExclusiveWhitelistSpots();
        }

        exclusiveWhitelistSpots[_addr] -= _amount;
        emit ExclusiveWhitelistSpotsRemoved(_addr, _amount);
    }

    function _clearExclusiveWhitelistSpots(address _addr) internal {
        uint256 amount = exclusiveWhitelistSpots[_addr];
        _removeExclusiveWhitelistSpots(_addr, amount);
    }
}
