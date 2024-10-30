// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";
import {Strategy} from "maat-strategies/contracts/Strategy.sol";

import {IWithdrawRequestLogic} from "../../src/interfaces/IExecutor.sol";

contract MaatVaultAdminFunctionsTesting is MaatVaultTestSetup {
    Strategy strategyUSDC;

    address public yearnVaultAddr = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1;
    address public USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function _afterSetUp() internal override {
        maatVault.removeStrategy(strategyId);

        MaatVaultV1 usdcVault = new MaatVaultV1(
            address(this),
            USDC,
            100,
            address(addressProvider),
            commander,
            watcher,
            1
        );

        IStrategyFromStrategies.StrategyParams
            memory strategyParams = IStrategyFromStrategies.StrategyParams(
                chainId,
                "YEARN",
                3,
                USDC,
                yearnUSDTVault
            );

        strategyUSDC = Strategy(
            address(
                new YearnV3Strategy(
                    strategyParams,
                    address(usdcVault),
                    feeToPerformance,
                    performanceFee
                )
            )
        );
    }

    function test_addStrategy() public {
        maatVault.addStrategy(address(strategy));

        (address strategyAddress, bool isActive) = maatVault.getStrategyById(
            strategyId
        );

        assertTrue(isActive);
        assertEq(strategyAddress, address(strategy));
    }

    function test_addStrategyFail() public {
        addressProvider.addStrategy(address(strategyUSDC));
        vm.expectRevert(
            "MaatVaultV1: Cannot add strategy with different asset"
        );
        maatVault.addStrategy(address(strategyUSDC));
    }

    function test_addStrategyFailBecauseStrategyAdded() public {
        maatVault.addStrategy(address(strategy));

        vm.expectRevert("MaatVaultV1: Strategy already exists");
        maatVault.addStrategy(address(strategy));
    }

    function test_removeStrategy() public {
        maatVault.addStrategy(address(strategy));

        (address strategyAddress, bool isActive) = maatVault.getStrategyById(
            strategyId
        );

        assertTrue(isActive);
        assertEq(strategyAddress, address(strategy));

        maatVault.removeStrategy(strategyId);

        vm.expectRevert("MaatVaultV1: Nonexistent strategy");
        (strategyAddress, isActive) = maatVault.getStrategyById(strategyId);
    }

    function test_removeStrategyFailNotExistRevert() public {
        vm.expectRevert("MaatVaultV1: Nonexistent strategy");
        maatVault.removeStrategy(strategyId);
    }

    function test_removeStrategyFailBecauseFunds() public {
        maatVault.addStrategy(address(strategy));

        deal(address(token), address(maatVault), 100);
        maatVault.depositInStrategy(strategyId, 100, bytes32("intentionId"));

        vm.expectRevert("MaatVaultV1: Cannot delete strategy with funds");
        maatVault.removeStrategy(strategyId);
    }

    function test_removeStrategyWithSharesWithoutAssets() public {
        maatVault.addStrategy(address(strategy));

        deal(address(strategy), address(maatVault), 100);

        maatVault.removeStrategy(strategyId);

        vm.expectRevert("MaatVaultV1: Nonexistent strategy");
        maatVault.getStrategyById(strategyId);
    }

    function test_toggleStrategy() public {
        maatVault.addStrategy(address(strategy));

        (address strategyAddress, bool isActive) = maatVault.getStrategyById(
            strategyId
        );

        assertTrue(isActive);
        assertEq(strategyAddress, address(strategy));

        maatVault.disableStrategy(strategyId);

        (strategyAddress, isActive) = maatVault.getStrategyById(strategyId);

        assertFalse(isActive);
        assertEq(strategyAddress, address(strategy));

        maatVault.enableStrategy(strategyId);

        (strategyAddress, isActive) = maatVault.getStrategyById(strategyId);

        assertTrue(isActive);
        assertEq(strategyAddress, address(strategy));
    }

    function test_enableStrategyFail() public {
        vm.expectRevert("MaatVaultV1: Nonexistent strategy");
        maatVault.enableStrategy(strategyId);
    }

    function test_disableStrategyFail() public {
        vm.expectRevert("MaatVaultV1: Nonexistent strategy");
        maatVault.disableStrategy(strategyId);
    }

    function test_AddRelatedVault() public {
        uint32 chainId = 123;
        uint32[] memory eids = new uint32[](1);
        eids[0] = chainId;

        address[] memory vaults = new address[](1);
        vaults[0] = address(address(this));

        maatVault.addRelatedVaults(eids, vaults);

        assertEq(maatVault.getRelatedVault(chainId), address(this));
    }

    function test_RemoveRelatedVault() public {
        uint32 chainId = 123;
        uint32[] memory eids = new uint32[](1);
        eids[0] = chainId;

        address[] memory vaults = new address[](1);
        vaults[0] = address(address(this));

        maatVault.addRelatedVaults(eids, vaults);

        maatVault.removeRelatedVault(chainId);

        vm.expectRevert("MaatVaultV1: Vault not found");
        maatVault.getRelatedVault(chainId);
    }

    function test_setCommander() public {
        address newCommander = address(0x12309);

        maatVault.setCommander(newCommander);

        assertEq(maatVault.commander(), newCommander);
    }

    function test_getMinAmount() public {
        maatVault.setMinAmount(100);

        assertEq(maatVault.minAmount(), 100);
    }

    function test_SetWithdrawCancelTimer() public {
        maatVault.setWithdrawCancellationDelay(1000);

        assertEq(maatVault.withdrawCancellationDelay(), 1000);
    }

    function test_SetEmergencyWithdrawalDelay() public {
        uint256 newDelay = 1000;

        uint256 initialDelay = maatVault.emergencyWithdrawalDelay();

        vm.expectEmit(true, true, true, true);
        emit IWithdrawRequestLogic.EmergencyWithdrawalDelayChanged(
            initialDelay,
            newDelay
        );
        maatVault.setEmergencyWithdrawalDelay(newDelay);

        assertEq(maatVault.emergencyWithdrawalDelay(), newDelay);
    }
}
