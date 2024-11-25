// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/* ====== External ====== */

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* ====== Interfaces ====== */

import {IMaatVaultV1} from "../../src/interfaces/IMaatVaultV1.sol";
import {IERC165} from "../lib/ERC165Registry.sol";
import {IExecutor} from "../interfaces/IExecutor.sol";
/* ====== Contracts ====== */

import {TokenKeeper} from "./base/TokenKeeper.sol";
import {Vault} from "./vault/Vault.sol";
import {Executor} from "./execute/Executor.sol";
import {IMaatSharesBridge} from "../interfaces/IMaatSharesBridge.sol";

contract MaatVaultV1 is IMaatVaultV1, Vault, Executor {
    using SafeERC20 for ERC20;

    bytes4 constant vaultInterfaceId = bytes4(keccak256("MAAT.V1.Vault"));

    constructor(
        address owner,
        address assetAddress,
        uint minAmount,
        address addressProvider,
        address commander,
        address watcher,
        uint32 chainEid
    )
        TokenKeeper(assetAddress)
        Executor(commander, watcher, chainEid)
        Vault(owner, assetAddress, addressProvider, minAmount)
    {
        _registerInterface(vaultInterfaceId);
        _registerInterface(type(IERC165).interfaceId);
    }

    /* ======== REQUEST FUNCTIONS ======== */

    ///@param shares Amount of shares to burn to withdraw funds
    ///@param dstEid dstEid of stargate adapter of the chain where user want to get tokens
    function requestWithdraw(
        uint shares,
        uint32 dstEid,
        address _owner,
        address receiver
    ) external nonReentrant returns (bytes32 intentionId) {
        uint amountOutTokens = _convertToAssetsByLowerPPS(shares);

        _validateMinAmount(amountOutTokens);
        _validateUser(_owner, msg.sender);

        require(
            dstEid == chainEid ||
                stargateAdapter().isTokenSupportedToBridge(
                    dstEid,
                    address(token)
                ),
            "MaatVaultV1: Chain is not supported for withdrawal"
        );

        intentionId = _generateIntentionId();

        this.transferFrom(msg.sender, address(this), shares);

        uint estimatedAmountOut = previewRedeem(shares);

        _createWithdrawRequest(
            intentionId,
            _owner,
            receiver,
            dstEid,
            shares,
            estimatedAmountOut
        );
    }

    ///@param data rebalance options for off-chain services
    function requestRebalance(
        bytes calldata data
    ) external onlyWatcherOrAdmin returns (bytes32 intentionId) {
        intentionId = _generateIntentionId();

        emit RebalanceRequested(intentionId, data);
    }

    /* ======== CANCEL WITHDRAW FUNCTION ======== */

    function cancelWithdrawal(
        bytes32 intentionId
    ) external nonReentrant returns (address owner, uint shares) {
        (address _owner, uint _shares) = _cancelWithdrawRequest(intentionId);

        this.transfer(_owner, _shares);

        return (_owner, _shares);
    }

    function _fulfillWithdrawRequest(bytes32 intentionId) internal override {
        WithdrawRequestInfo memory request = getWithdrawRequest(intentionId);

        uint amountOut = _redeem(request.shares, address(this), address(this));

        _cleanRequestInfo(intentionId);

        if (request.dstEid == chainEid) {
            token.safeTransfer(request.receiver, amountOut);
        } else {
            _bridgeToUser(amountOut, request.receiver, request.dstEid);
        }

        emit WithdrawRequestFulfilled(
            amountOut,
            request.owner,
            request.receiver,
            intentionId
        );
    }

    /**
     * @notice Emergency withdraw function to rescue funds from strategies if commander does not fullfil withdraw request
     * @notice this function only can be called after emergencyWithdrawalDelay time passed after creation time of the request
     */
    function emergencyWithdraw(
        bytes32 intentionIdOfFailedWithdrawRequest,
        ActionInput[] calldata withdrawInputs
    ) external {
        _validateWithdrawRequestExistence(intentionIdOfFailedWithdrawRequest);

        WithdrawRequestInfo memory request = getWithdrawRequest(
            intentionIdOfFailedWithdrawRequest
        );

        require(
            request.creationTime + emergencyWithdrawalDelay <= block.timestamp,
            "WithdrawRequestLogic: Not enough time has passed yet to withdraw"
        );

        uint256 i = 0;
        uint256 amountWithdrawn = 0;
        uint256 amountToWithdraw = _convertToAssetsByLowerPPS(request.shares);

        while (idle() < amountToWithdraw && i < withdrawInputs.length) {
            uint256 balanceBefore = token.balanceOf(address(this));
            _withdrawFromStrategy(
                withdrawInputs[i].strategyId,
                withdrawInputs[i].amount,
                intentionIdOfFailedWithdrawRequest
            );
            uint256 balanceAfter = token.balanceOf(address(this));
            amountWithdrawn += balanceAfter - balanceBefore;
            i++;
        }

        // some strategies might withdraw less than expected assets,
        // so we allow up to 105% for to be withdrawn in idle
        if (amountWithdrawn > (amountToWithdraw * 105) / 100)
            revert EmergencyWithdrawalTooMuchWithdrawn(
                amountWithdrawn,
                amountToWithdraw
            );

        _fulfillWithdrawRequest(intentionIdOfFailedWithdrawRequest);
    }

    /* ====== SHARES BRIDGE ====== */
    error NotSharesBridge(address caller, address bridge);

    function finishSharesBridge(address account, uint256 value) external {
        address sharesBridge = addressProvider().sharesBridge();
        if (sharesBridge != msg.sender)
            revert NotSharesBridge(msg.sender, sharesBridge);

        _mint(account, value);
    }

    function bridgeShares(
        uint32 _dstEid,
        uint256 _amount,
        bytes calldata options
    ) external payable {
        if (_amount == 0) revert AmountIsTooLow();
        address sharesBridge = addressProvider().sharesBridge();

        _burn(msg.sender, _amount);

        IMaatSharesBridge.BridgeData memory data = IMaatSharesBridge.BridgeData(
            msg.sender,
            _amount,
            getRelatedVault(_dstEid)
        );

        IMaatSharesBridge(sharesBridge).bridge{value: msg.value}(
            _dstEid,
            data,
            options
        );
    }
}
