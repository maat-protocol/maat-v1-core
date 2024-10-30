// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IExecutor} from "../../interfaces/IExecutor.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";

import {Roles} from "./Roles.sol";
import {BridgeLogic} from "./BridgeLogic.sol";
import {StrategyManager} from "./StrategyManager.sol";
import {WithdrawRequestLogic} from "./WithdrawRequestLogic.sol";
import {RelatedVaultManager} from "../base/RelatedVaultManager.sol";
import {IntentionGenerator} from "../base/IntentionGenerator.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Executor is
    IntentionGenerator,
    Roles,
    RelatedVaultManager,
    StrategyManager,
    WithdrawRequestLogic,
    BridgeLogic,
    IExecutor
{
    using SafeERC20 for ERC20;

    constructor(
        address commander,
        address watcher,
        uint32 chainEid
    ) Roles(commander, watcher) WithdrawRequestLogic(chainEid) {}

    /* ======== EXECUTION FUNCTION ======== */

    ///@notice execute multiple actions from commander
    ///@dev arguments of the function are must not be encoded and arrays must be same length
    function execute(
        // TODO: make batching more clear with intention Ids
        ActionType[] calldata actionType,
        ActionInput[] calldata inputs
    ) external onlyCommanderOrAdmin returns (bool) {
        uint length = actionType.length;

        require(length == inputs.length, "MaatVaultV1: Invalid input length");
        require(length > 0, "MaatVaultV1: Empty input");

        for (uint i = 0; i < length; i++) {
            _execute(actionType[i], inputs[i]);
        }

        return true;
    }

    function _execute(ActionType _type, ActionInput memory input) internal {
        uint32 dstEid = input.dstEid;
        bytes32 strategyId = input.strategyId;
        uint256 _amount = input.amount;
        bytes32 intentionId = input.intentionId;

        if (_type == ActionType.DEPOSIT) {
            _depositInStrategy(strategyId, _amount, intentionId);
        } else if (_type == ActionType.WITHDRAW) {
            _withdrawFromStrategy(strategyId, _amount, intentionId);
        } else if (_type == ActionType.BRIDGE) {
            _bridge(_amount, dstEid, intentionId);
        } else if (_type == ActionType.FULFILL_WITHDRAW_REQUEST) {
            _fulfillWithdrawRequest(intentionId);
        }
    }

    // TODO: rename depositToStrategy
    function _depositInStrategy(
        bytes32 _strategyId,
        uint amount,
        bytes32 intentionId
    ) internal returns (uint shares) {
        (address strategyAddress, bool isActive) = getStrategyById(_strategyId);

        require(isActive, "MaatVaultV1: Strategy is not active");

        IStrategy strategy = IStrategy(strategyAddress);

        token.safeIncreaseAllowance(strategyAddress, amount);

        shares = strategy.deposit(amount, address(this));

        _decreaseIdle(amount);

        emit DepositedInStrategy(_strategyId, amount, intentionId);
    }

    ///@dev amount is in asset() token
    function _withdrawFromStrategy(
        bytes32 _strategyId,
        uint amount,
        bytes32 intentionId
    ) internal returns (uint shares) {
        (address strategyAddress, ) = getStrategyById(_strategyId);

        IStrategy strategy = IStrategy(strategyAddress);

        // Some strategies may withdraw less assets than requested, so it is important that the calculations are correct.
        uint256 balanceBefore = token.balanceOf(address(this));
        shares = strategy.withdraw(amount, address(this), address(this));
        uint256 balanceAfter = token.balanceOf(address(this));

        _increaseIdle(balanceAfter - balanceBefore);

        emit WithdrewFromStrategy(_strategyId, amount, intentionId);
    }

    function _fulfillWithdrawRequest(bytes32 intentionId) internal virtual {}
}
