// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract TestUtils is Test {
    mapping(uint32 chainId => string envString) forkURLs;

    constructor() {
        forkURLs[1] = "ETHEREUM_RPC";
        forkURLs[42161] = "ARBITRUM_RPC";
    }

    function fork(uint32 chainId, uint forkBlockNumber) public {
        string memory envString = forkURLs[chainId];

        vm.createSelectFork(vm.envString(envString), forkBlockNumber);
    }
}
