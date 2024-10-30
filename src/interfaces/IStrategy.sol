// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

interface IStrategy is IERC4626 {
    struct StrategyParams {
        uint32 chainId;
        string protocol;
        uint8 protocolVersion;
        address token;
        address protocolVault;
    }

    function getStrategyParams() external view returns (StrategyParams memory);

    function getStrategyId() external view returns (bytes32 strategyId);
}
