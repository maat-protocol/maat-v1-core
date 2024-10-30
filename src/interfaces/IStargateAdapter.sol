// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStargateAdapter {
    event BridgeTokens(
        bytes32 guid,
        address bridgeIniter,
        bytes32 intentionId,
        uint32 dstEid,
        address _vault,
        address token,
        uint256 amountIn,
        uint256 lzFee
    );

    event BridgeTokensToReceiver(
        bytes32 guid,
        uint32 dstEid,
        uint32 poolId,
        uint256 amountIn,
        address receiver
    );

    event ReceivedOnDestination(
        bytes32 guid,
        address bridgeIniter,
        uint256 receivedAmountLD,
        address vault,
        address executor,
        bytes extraData,
        bytes32 intentionId
    );

    event DepositedOnDestination(bool success);

    /// @notice sends token to StargateAdapter on destination chain
    function sendTokens(
        address vault,
        uint32 dstEid, // endpoint ID on destination chain
        address srcToken, // token address on source chain
        uint amountLD, // amount in in Local Decimals
        bytes32 intentionId // encoded data for the Vault on destination chain
    ) external;

    function sendTokensToReceiver(
        uint32 dstEid, // endpoint ID on destination chain
        address srcToken, // token address on source chain
        uint amountLD, // amount in in Local Decimals
        address receiver // receiver address on destination chain
    ) external;

    function isTokenSupportedToBridge(
        uint32 _dstEid,
        address token
    ) external view returns (bool);
}
