// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {AddressProviderKeeper} from "../base/AddressProviderKeeper.sol";
import {TokenKeeper} from "../base/TokenKeeper.sol";

import {IStrategyManager} from "../../interfaces/IExecutor.sol";
import {IStrategy} from "../../interfaces/IStrategy.sol";

abstract contract StrategyManager is
    Ownable,
    AddressProviderKeeper,
    TokenKeeper,
    IStrategyManager
{
    mapping(bytes32 => Strategy) private _supportedStrategies;
    mapping(address => bytes32) private _strategyAddressToId;

    /* ====== EXTERNAL ====== */

    ///@dev strategy is active after adding by default
    function addStrategy(address strategy) external onlyOwner {
        require(
            addressProvider().isStrategy(strategy),
            "MaatVaultV1: Invalid strategy"
        );

        bytes32 strategyId = IStrategy(strategy).getStrategyId();

        require(
            IStrategy(strategy).asset() == address(token),
            "MaatVaultV1: Cannot add strategy with different asset"
        );

        require(
            _supportedStrategies[strategyId].strategyAddress == address(0),
            "MaatVaultV1: Strategy already exists"
        );

        _supportedStrategies[strategyId].strategyAddress = strategy;
        _supportedStrategies[strategyId].isActive = true;

        _strategyAddressToId[strategy] = strategyId;

        emit StrategyAdded(strategyId);
    }

    /**
     * @dev Cannot remove strategy with funds
     * Vault must have 0 shares in strategy or strategy must have 0 total assets
     */
    function removeStrategy(bytes32 strategyId) external onlyOwner {
        _validateStrategyExistence(strategyId);

        IStrategy strategy = IStrategy(
            _supportedStrategies[strategyId].strategyAddress
        );

        require(
            strategy.balanceOf(address(this)) == 0 ||
                strategy.totalAssets() == 0,
            "MaatVaultV1: Cannot delete strategy with funds"
        );

        _deleteStrategy(strategyId, address(strategy));
    }

    // TODO: review such functionality requirement
    // disabling of strategies should be on a AddressProvider
    // should think about strategy deprecation after disable it on AddressProvider
    function enableStrategy(bytes32 strategyId) external onlyOwner {
        _validateStrategyExistence(strategyId);

        _toggleStrategy(strategyId, true);
    }

    function disableStrategy(bytes32 strategyId) external onlyOwner {
        _validateStrategyExistence(strategyId);

        _toggleStrategy(strategyId, false);
    }

    /* ====== INTERNALS ====== */

    function _deleteStrategy(bytes32 strategyId, address strategy) internal {
        delete _supportedStrategies[strategyId];
        delete _strategyAddressToId[strategy];
    }

    function _toggleStrategy(bytes32 strategyId, bool isActive) internal {
        _supportedStrategies[strategyId].isActive = isActive;

        emit StrategyToggled(strategyId, isActive);
    }

    /* ====== VIEWS ====== */

    function getStrategyByAddress(
        address strategy
    ) external view returns (bytes32, bool) {
        _validateStrategyExistence(strategy);

        return (
            _strategyAddressToId[strategy],
            _supportedStrategies[_strategyAddressToId[strategy]].isActive
        );
    }

    function getStrategyById(
        bytes32 strategyId
    ) public view returns (address, bool) {
        _validateStrategyExistence(strategyId);

        return (
            _supportedStrategies[strategyId].strategyAddress,
            _supportedStrategies[strategyId].isActive
        );
    }

    function _validateStrategyExistence(bytes32 strategyId) internal view {
        address strategy = _supportedStrategies[strategyId].strategyAddress;

        require(strategy != address(0), "MaatVaultV1: Nonexistent strategy");
    }

    function _validateStrategyExistence(address strategy) internal view {
        bytes32 strategyId = _strategyAddressToId[strategy];

        require(strategyId != bytes32(0), "MaatVaultV1: Nonexistent strategy");
    }
}
