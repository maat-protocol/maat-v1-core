// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IWithdrawRequestLogic} from "../../interfaces/IExecutor.sol";
import {RelatedVaultManager} from "../base/RelatedVaultManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract WithdrawRequestLogic is
    RelatedVaultManager,
    IWithdrawRequestLogic
{
    uint internal _withdrawCancellationDelay = 1 hours;
    uint256 public emergencyWithdrawalDelay = 3 days;

    ///@dev Endpoint Id of current chain in stargate terminology
    uint32 public immutable chainEid;

    mapping(bytes32 intentionId => WithdrawRequestInfo)
        private _withdrawRequests;

    constructor(uint32 _chainEid) {
        chainEid = _chainEid;
    }

    error EmergencyWithdrawalTooMuchWithdrawn(
        uint256 amountWithdrawn,
        uint256 amountToWithdraw
    );

    /* ======== EXTERNAL ======== */

    function setWithdrawCancellationDelay(uint timer) external onlyOwner {
        emit WithdrawCancellationDelayChanged(
            _withdrawCancellationDelay,
            timer
        );

        _withdrawCancellationDelay = timer;
    }

    function setEmergencyWithdrawalDelay(uint timer) external onlyOwner {
        emit EmergencyWithdrawalDelayChanged(emergencyWithdrawalDelay, timer);

        emergencyWithdrawalDelay = timer;
    }

    /* ======== INTERNAL ======== */

    function _createWithdrawRequest(
        bytes32 intentionId,
        address _owner,
        address receiver,
        uint32 dstEid,
        uint shares,
        uint estimatedAmountOut
    ) internal {
        // TODO: add validations for all params possible
        require(
            receiver != address(0),
            "WithdrawRequestLogic: Receiver is zero address"
        );

        require(
            _withdrawRequests[intentionId].creationTime == 0,
            "WithdrawRequestLogic: Request already exists"
        );

        _withdrawRequests[intentionId] = WithdrawRequestInfo({
            owner: _owner,
            receiver: receiver,
            dstEid: dstEid,
            creationTime: uint32(block.timestamp),
            shares: shares
        });

        emit WithdrawalRequested(
            shares,
            estimatedAmountOut,
            _owner,
            intentionId,
            dstEid
        );
    }

    function _cancelWithdrawRequest(
        bytes32 intentionId
    ) internal returns (address owner, uint shares) {
        WithdrawRequestInfo memory request = _withdrawRequests[intentionId];

        require(
            request.creationTime != 0,
            "WithdrawRequestLogic: Request does not exist"
        );

        require(
            request.creationTime + _withdrawCancellationDelay <=
                block.timestamp,
            "WithdrawRequestLogic: Not enough time has passed yet to withdraw"
        );
        address _owner = request.owner;

        require(
            msg.sender == _owner,
            "WithdrawRequestLogic: Unauthorized caller"
        );

        _cleanRequestInfo(intentionId);

        emit WithdrawRequestCancelled(intentionId);

        return (_owner, request.shares);
    }

    function _cleanRequestInfo(bytes32 intentionId) internal {
        delete _withdrawRequests[intentionId];
    }

    /* ======== VIEWS ======== */

    function getWithdrawRequest(
        bytes32 intentionId
    ) public view returns (WithdrawRequestInfo memory) {
        _validateWithdrawRequestExistence(intentionId);

        return _withdrawRequests[intentionId];
    }

    function withdrawCancellationDelay() public view returns (uint) {
        return _withdrawCancellationDelay;
    }

    function _validateWithdrawRequestExistence(
        bytes32 intentionId
    ) internal view {
        WithdrawRequestInfo memory request = _withdrawRequests[intentionId];

        require(request.owner != address(0), "MaatVaultV1: Request not found");
    }
}
