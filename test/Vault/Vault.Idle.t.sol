// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";
import {StargateAdapterMock} from "../mock/StargateAdapterMock.sol";

contract MaatVaultIdleTesting is MaatVaultTestSetup {
    address buyer = address(0xdeadaaaadead);

    StargateAdapterMock stargateAdapter;
    MaatVaultHarness secondMaatVault;

    function _afterSetUp() internal override {
        deal(address(token), address(this), 10 ** 30);
        maatVault.setIdle(0);

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

    function testFuzzing_Deposit_IdleChange(uint assets) public {
        vm.assume(assets > amountMin && assets < 2 ** 112 - 1);
        deal(address(token), buyer, assets + 1);

        vm.startPrank(buyer);
        token.approve(address(maatVault), assets);
        maatVault.deposit(assets, buyer);

        token.transfer(address(maatVault), 1);
        assertEq(maatVault.idle(), assets);
    }

    function testFuzzing_Mint_IdleChange(uint shares) public {
        vm.assume(shares > amountMin && shares < 2 ** 112 - 1);
        deal(address(token), buyer, shares + 1);

        vm.startPrank(buyer);
        token.approve(address(maatVault), shares);
        maatVault.mint(shares, buyer);

        token.transfer(address(maatVault), 1);
        assertEq(maatVault.idle(), maatVault.convertToAssets(shares));
    }

    function testFuzzing_Withdraw_IdleChange(uint assets, uint dust) public {
        vm.assume(assets > amountMin && assets < 2 ** 112 - 1);
        vm.assume(dust <= assets);
        deal(address(maatVault), buyer, maatVault.previewWithdraw(assets));
        deal(address(token), address(maatVault), assets + dust);

        maatVault.setIdle(assets + dust);

        uint initialBalanceVault = token.balanceOf(address(maatVault));

        vm.startPrank(buyer);
        maatVault.approve(address(maatVault), assets);
        maatVault.withdraw(assets, buyer, buyer);

        token.transfer(address(maatVault), 1);
        assertEq(maatVault.idle(), initialBalanceVault - assets);
    }

    function testFuzzing_Redeem_IdleChanged(uint shares, uint dust) public {
        vm.assume(shares > amountMin && shares < 2 ** 112 - 1);
        vm.assume(dust <= shares);
        deal(address(maatVault), buyer, maatVault.previewWithdraw(shares));
        deal(address(token), address(maatVault), shares + dust);

        maatVault.setIdle(shares + dust);

        uint initialBalanceVault = token.balanceOf(address(maatVault));

        vm.startPrank(buyer);
        maatVault.approve(address(maatVault), shares);
        maatVault.redeem(shares, buyer, buyer);

        token.transfer(address(maatVault), 1);
        assertEq(
            maatVault.idle(),
            initialBalanceVault - maatVault.previewRedeem(shares)
        );
    }

    function testFuzzing_DepositInStrategy_IdleChanged(
        uint amountToDeposit
    ) public {
        vm.assume(amountToDeposit > amountMin && amountToDeposit < 10 ** 10);
        deal(address(token), address(maatVault), amountToDeposit);
        maatVault.setIdle(amountToDeposit);

        token.approve(address(maatVault), amountToDeposit);
        maatVault.depositInStrategy(strategyId, amountToDeposit, bytes32(0));

        token.transfer(address(maatVault), 1);
        assertEq(maatVault.idle(), 0);
    }

    function testFuzzing_WithdrawFromStrategy_IdleChanged(
        uint amountToWithdraw
    ) public {
        vm.assume(amountToWithdraw > amountMin && amountToWithdraw < 10 ** 10);
        deal(address(token), address(maatVault), amountToWithdraw + 100);
        deal(address(token), address(strategy), amountToWithdraw + 100);

        maatVault.setIdle(amountToWithdraw + 100);

        token.approve(address(maatVault), amountToWithdraw + 2);
        maatVault.depositInStrategy(
            strategyId,
            amountToWithdraw + 2,
            bytes32(0)
        );

        uint idleBefore = maatVault.idle();
        maatVault.withdrawFromStrategy(
            strategyId,
            amountToWithdraw,
            bytes32(0)
        );

        token.transfer(address(maatVault), 1);

        assertEq(maatVault.idle(), idleBefore + amountToWithdraw);
    }

    function testFuzzing_Bridge_IdleChanged(uint amountToBridge) public {
        vm.assume(amountToBridge > amountMin && amountToBridge < 10 ** 10);
        deal(address(token), address(maatVault), amountToBridge);
        deal(address(token), address(strategy), amountToBridge);

        maatVault.setIdle(amountToBridge);

        maatVault.bridge(amountToBridge, 2, bytes32(0));

        token.transfer(address(maatVault), 1);
        token.transfer(address(secondMaatVault), 1);

        assertEq(maatVault.idle(), 0);
        assertEq(secondMaatVault.idle(), amountToBridge);
    }

    //REVERT TESTS
    function testFuzzing_Withdraw_RevertIf_IdleIncorrect(
        uint assets,
        uint dust
    ) public {
        vm.assume(assets > amountMin && assets < 2 ** 112 - 1);
        vm.assume(dust <= assets);
        deal(address(maatVault), buyer, maatVault.previewWithdraw(assets));
        deal(address(token), address(maatVault), assets + dust);

        maatVault.setIdle(0);

        vm.startPrank(buyer);
        maatVault.approve(address(maatVault), assets);

        vm.expectRevert(
            "MaatVaultV1: Arithmetic error during idle calculations"
        );
        maatVault.withdraw(assets, buyer, buyer);
    }

    function testFuzzing_Redeem_RevertIf_IdleIncorrect(
        uint shares,
        uint dust
    ) public {
        vm.assume(shares > amountMin && shares < 2 ** 112 - 1);
        vm.assume(dust <= shares);
        deal(address(maatVault), buyer, maatVault.previewWithdraw(shares));
        deal(address(token), address(maatVault), shares + dust);

        maatVault.setIdle(0);

        vm.startPrank(buyer);
        maatVault.approve(address(maatVault), shares);

        vm.expectRevert(
            "MaatVaultV1: Arithmetic error during idle calculations"
        );
        maatVault.redeem(shares, buyer, buyer);
    }

    function testFuzzing_DepositItStrategy_RevertIf_IdleIncorrect(
        uint amountToDeposit
    ) public {
        vm.assume(amountToDeposit > amountMin && amountToDeposit < 10 ** 10);
        deal(address(token), address(maatVault), amountToDeposit);
        maatVault.setIdle(0);

        token.approve(address(maatVault), amountToDeposit);

        vm.expectRevert(
            "MaatVaultV1: Arithmetic error during idle calculations"
        );
        maatVault.depositInStrategy(strategyId, amountToDeposit, bytes32(0));
    }

    function testFuzzing_Bridge_RevertIf_IdleIncorrect(
        uint amountToBridge
    ) public {
        vm.assume(amountToBridge > amountMin && amountToBridge < 10 ** 10);
        deal(address(token), address(maatVault), amountToBridge);
        deal(address(token), address(strategy), amountToBridge);

        maatVault.setIdle(0);

        vm.expectRevert(
            "MaatVaultV1: Arithmetic error during idle calculations"
        );
        maatVault.bridge(amountToBridge, 2, bytes32(0));
    }
}
