// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract FeeManager is Ownable {
    uint64 private _feeIn = 5 * 10 ** 5;
    uint64 private _feeOut = 5 * 10 ** 5;
    uint64 public constant feePrecision = 10 ** 8;
    uint public constant maxFee = 5 * 10 ** 6;

    address private _feeTo;

    constructor(address feeTo_) {
        require(feeTo_ != address(0), "MaatVaultV1: FeeTo is zero address");
        _feeTo = feeTo_;
    }

    /* ====== SETTER ====== */

    event FeeChanged(
        uint64 prevFeeIn,
        uint64 newFeeIn,
        uint64 prevFeeOut,
        uint64 newFeeOut
    );

    function setFees(uint64 feeIn_, uint64 feeOut_) external onlyOwner {
        require(
            feeIn_ < maxFee && feeOut_ < maxFee,
            "MaatVaultV1: Fee is more than max value"
        );

        emit FeeChanged(_feeIn, feeIn_, _feeOut, feeOut_);

        _feeIn = feeIn_;
        _feeOut = feeOut_;
    }

    function setFeeTo(address feeTo_) external onlyOwner {
        require(feeTo_ != address(0), "MaatVaultV1: FeeTo is zero address");

        _feeTo = feeTo_;
    }

    /* ====== INTERNAL ====== */

    function _calculateFee(
        uint amount,
        uint112 fee
    ) internal pure returns (uint) {
        return (amount * fee) / feePrecision;
    }

    /* ====== VIEWS ====== */

    function feeIn() public view returns (uint112) {
        return _feeIn;
    }

    function feeOut() public view returns (uint112) {
        return _feeOut;
    }

    function feeTo() public view returns (address) {
        return _feeTo;
    }
}
