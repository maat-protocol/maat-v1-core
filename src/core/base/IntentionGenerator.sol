// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract IntentionGenerator {
    uint internal nonce = 0;

    function _generateIntentionId() internal returns (bytes32 intentionId) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        intentionId = keccak256(
            abi.encodePacked(address(this), nonce, chainId)
        );
        nonce++;
    }
}
