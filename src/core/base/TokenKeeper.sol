// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenKeeper {
    using SafeERC20 for ERC20;
    ERC20 public immutable token;

    uint private _idle;

    constructor(address _token) {
        token = ERC20(_token);
    }

    function _increaseIdle(uint value) internal virtual {
        _idle += value;
    }

    function _decreaseIdle(uint value) internal virtual {
        require(
            value <= _idle,
            "MaatVaultV1: Arithmetic error during idle calculations"
        );
        _idle -= value;
    }

    function idle() public view virtual returns (uint) {
        return _idle;
    }
}
