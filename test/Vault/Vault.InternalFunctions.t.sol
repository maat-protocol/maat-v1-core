// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";
import {StargateAdapterMock} from "../mock/StargateAdapterMock.sol";

contract MaatVaultInternalFunctionsTesting is MaatVaultTestSetup {
    StargateAdapterMock stargateAdapter;
    MaatVaultHarness secondMaatVault;

    function _afterSetUp() internal override {
        stargateAdapter = new StargateAdapterMock();

        secondMaatVault = new MaatVaultHarness(
            address(this),
            address(token),
            amountMin,
            address(addressProvider),
            commander,
            watcher,
            2
        );
        addressProvider.changeStargateAdapter(address(stargateAdapter));

        stargateAdapter.setPeer(uint32(2), address(secondMaatVault));
        uint32[] memory eids = new uint32[](1);
        eids[0] = 2;

        address[] memory vaults = new address[](1);
        vaults[0] = address(secondMaatVault);

        maatVault.addRelatedVaults(eids, vaults);
    }

    function testFuzzing_DepositInStrategy(
        uint randomBalance,
        uint amountToDeposit
    ) public {
        vm.assume(randomBalance > 10);
        vm.assume(amountToDeposit > 10);
        vm.assume(randomBalance >= amountToDeposit);
        vm.assume(amountToDeposit < strategy.maxDeposit(address(maatVault)));

        deal(address(token), address(maatVault), randomBalance);
        maatVault.depositInStrategy(
            strategyId,
            amountToDeposit,
            bytes32("intentionId")
        );

        assertEq(strategy.balanceOf(address(maatVault)), amountToDeposit);
        assertEq(
            token.balanceOf(address(maatVault)),
            randomBalance - amountToDeposit
        );
    }

    function testFuzzing_WithdrawFromStrategy(
        uint randomBalance,
        uint amountToDeposit,
        uint amountToWithdraw
    ) public {
        vm.assume(randomBalance > 0);
        vm.assume(amountToDeposit > 0);
        vm.assume(amountToWithdraw > 1);
        vm.assume(randomBalance >= amountToDeposit);
        vm.assume(amountToDeposit < strategy.maxDeposit(address(maatVault)));
        vm.assume(amountToWithdraw <= amountToDeposit);

        deal(address(token), address(maatVault), randomBalance);

        maatVault.depositInStrategy(
            strategyId,
            amountToDeposit,
            bytes32("intentionId")
        );

        uint withdrawable = IERC4626(yearnUSDTVault).maxWithdraw(
            address(strategy)
        );

        uint potentialLoss = 2 wei;

        assertApproxEqAbs(
            withdrawable,
            amountToDeposit,
            potentialLoss,
            "Loss in funds is not less or eq than 2 wei"
        );

        amountToWithdraw = amountToWithdraw > withdrawable
            ? withdrawable
            : amountToWithdraw;

        maatVault.withdrawFromStrategy(
            strategyId,
            amountToWithdraw,
            bytes32("intentionId")
        );

        assertApproxEqAbs(
            strategy.balanceOf(address(maatVault)),
            amountToDeposit - amountToWithdraw,
            potentialLoss
        );
        assertApproxEqAbs(
            token.balanceOf(address(maatVault)),
            randomBalance - amountToDeposit + amountToWithdraw,
            potentialLoss
        );
    }

    function test_ExistenceOfStrategy() public {
        bytes32 fakeStrategyId = keccak256(abi.encode(address(0x123)));

        uint initialBalance = 10 ** 18;

        deal(address(token), address(maatVault), initialBalance);

        vm.expectRevert("MaatVaultV1: Nonexistent strategy");
        maatVault.depositInStrategy(
            fakeStrategyId,
            100,
            bytes32("intentionId")
        );
    }

    function test_StrategyActivity() public {
        uint initialBalance = 10 ether;
        deal(address(token), address(maatVault), initialBalance);

        uint amount = 10 ** token.decimals();

        //Deposit case
        maatVault.disableStrategy(strategyId);

        (, bool isActive) = maatVault.getStrategyById(strategyId);
        assertFalse(isActive);

        vm.expectRevert("MaatVaultV1: Strategy is not active");
        maatVault.depositInStrategy(strategyId, amount, bytes32("intentionId"));

        //Withdraw Case
        maatVault.enableStrategy(strategyId);

        (, isActive) = maatVault.getStrategyById(strategyId);
        assertTrue(isActive);

        maatVault.depositInStrategy(strategyId, amount, bytes32("intentionId"));

        maatVault.disableStrategy(strategyId);

        (, isActive) = maatVault.getStrategyById(strategyId);
        assertFalse(isActive);

        uint loss = 1 wei;
        maatVault.withdrawFromStrategy(
            strategyId,
            amount - loss,
            bytes32("intentionId")
        );
    }

    function testFuzzing_Bridge(
        uint initialBalance,
        uint amountToBridge
    ) public {
        vm.assume(initialBalance < 10 ** 50);
        vm.assume(amountToBridge < initialBalance);

        deal(address(token), address(maatVault), initialBalance);

        maatVault.bridge(amountToBridge, 2, bytes32(0));

        assertEq(
            token.balanceOf(address(maatVault)),
            initialBalance - amountToBridge
        );
        assertEq(token.balanceOf(address(secondMaatVault)), amountToBridge);
    }
}
