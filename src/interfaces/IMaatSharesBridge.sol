// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IMaatSharesBridge {
    event SendShares(
        bytes32 indexed guid,
        address indexed user,
        address srcVault,
        address dstVault,
        uint256 amount,
        uint32 dstEid
    );

    event ReceiveShares(
        bytes32 indexed guid,
        address indexed user,
        address vault,
        uint256 amount
    );

    struct BridgeData {
        address user;
        uint256 amount;
        address targetVault;
    }

    error NotMaatVault();

    function bridge(
        uint32 _dstEid,
        BridgeData memory data,
        bytes calldata _options
    ) external payable;
}
