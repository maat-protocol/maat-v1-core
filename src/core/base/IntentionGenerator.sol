// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract IntentionGenerator {
    // To mitigate the re-org risk, we use a nonce for every EOA
    // EOAs txs order can't be reorged due to nonce restrictions
    // msg.sender can be a contract, that is used by multiple users as router
    // so we use tx.origin
    mapping(address => uint) internal _nonces;

    function _generateIntentionId() internal returns (bytes32 intentionId) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        intentionId = keccak256(
            abi.encodePacked(
                address(this),
                tx.origin,
                _nonces[tx.origin],
                chainId
            )
        );
        _nonces[tx.origin]++;
    }
}
