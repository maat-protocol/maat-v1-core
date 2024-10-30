// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWithdrawRequestLogic {
    /* ====== STRUCT ====== */

    struct WithdrawRequestInfo {
        address owner;
        address receiver;
        uint32 dstEid;
        uint32 creationTime;
        uint256 shares;
    }

    /* ====== EVENTS ====== */

    event WithdrawRequestCancelled(bytes32 indexed intentionId);

    event WithdrawalRequested(
        uint256 shares,
        uint256 estimatedAmountOut,
        address owner,
        bytes32 indexed intentionId,
        uint32 dstEid
    );

    event WithdrawRequestFulfilled(
        uint256 assets,
        address owner,
        address receiver,
        bytes32 indexed intentionId
    );

    event WithdrawCancellationDelayChanged(uint256 prevDelay, uint newDelay);
    event EmergencyWithdrawalDelayChanged(uint256 prevDelay, uint newDelay);

    /* ====== FUNCTIONS ====== */

    function getWithdrawRequest(
        bytes32 intentionId
    ) external view returns (WithdrawRequestInfo memory);

    function emergencyWithdrawalDelay() external view returns (uint);
}

interface IBridgeLogic {
    /* ====== EVENTS ====== */

    event Bridged(
        uint32 dstEid,
        address asset,
        uint256 amount,
        bytes32 indexed intentionId
    );

    event BridgeFinished(uint amount, uint32 originEid, bytes32 intentionId);

    /* ====== FUNCTIONS ====== */

    function finishBridge(
        uint256 amountBridged,
        uint32 originEid,
        bytes32 intentionId
    ) external;
}

interface IStrategyManager {
    /* ====== STRUCT ====== */

    struct Strategy {
        address strategyAddress;
        bool isActive;
    }

    /* ====== EVENTS ====== */

    event StrategyAdded(bytes32 strategyId);
    event StrategyRemoved(bytes32 strategyId);
    event StrategyToggled(bytes32 strategyId, bool isActive);

    /* ====== FUNCTIONS ====== */

    function getStrategyById(
        bytes32 _strategyId
    ) external view returns (address, bool);

    function getStrategyByAddress(
        address _strategy
    ) external view returns (bytes32, bool);

    /// @notice Adds a new strategy to the list of valid strategies in the contract.
    /// @dev This function requires that the caller is an administrator or has appropriate access rights.
    function addStrategy(address strategy) external;

    /// @notice Delete a strategy from the list of valid strategies in the contract.
    /// @dev Requires that the caller is an administrator or has appropriate access rights.
    function removeStrategy(bytes32 _strategyId) external;

    ///@notice Deactivate a strategy in the contract. Deactivated strategies will not be able to perform any actions.
    function disableStrategy(bytes32 _strategyId) external;

    ///@notice Turn on a strategy
    function enableStrategy(bytes32 _strategyId) external;
}

interface IRoles {
    function setCommander(address _commander) external;
}

interface IExecutor is IWithdrawRequestLogic, IBridgeLogic, IStrategyManager {
    ///@dev Used to Deposit/Withdraw from strategy, Bridge assets between MaatVaultV1, Fulfill Requests
    enum ActionType {
        DEPOSIT,
        WITHDRAW,
        BRIDGE,
        FULFILL_WITHDRAW_REQUEST
    }

    ///@notice Not all fields are required for all actions
    struct ActionInput {
        uint32 dstEid;
        bytes32 strategyId;
        uint256 amount;
        bytes32 intentionId;
    }

    function execute(
        ActionType[] calldata actionType,
        ActionInput[] calldata inputs
    ) external returns (bool);

    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares,
        bytes32 indexed intentionId
    );

    event DepositedInStrategy(
        bytes32 strategyId,
        uint256 amount,
        bytes32 indexed intentionId
    );

    event WithdrewFromStrategy(
        bytes32 strategyId,
        uint256 amount,
        bytes32 indexed intentionId
    );

    event RebalanceRequested(bytes32 intentionId, bytes data);

    function requestRebalance(
        bytes calldata data
    ) external returns (bytes32 intentionId);

    function requestWithdraw(
        uint shares,
        uint32 dstEid,
        address receiver,
        address owner
    ) external returns (bytes32);
}
