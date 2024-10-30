// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";

contract MaatVaultFeeTesting is MaatVaultTestSetup {
    address buyer = address(0x031);
    address feeTo = address(this);

    function _afterSetUp() internal override {
        maatVault.setFeeTo(feeTo);
        deal(address(token), buyer, 10 ** 30);
        deal(address(token), address(maatVault), 10 ** 60);
        deal(address(maatVault), buyer, 10 ** 50);

        address[] memory vaultsArray = new address[](1);
        vaultsArray[0] = address(maatVault);

        uint112[] memory ppsArray = new uint112[](1);
        ppsArray[0] = 14612431;

        skip(10);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);
        skip(10);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);
    }

    function testFuzzing_FeeDeposit(uint amountIn, uint64 feeIn) public {
        vm.assume(feeIn > 10 ** 6 && feeIn < 5 * 10 ** 6);
        vm.assume(amountIn > 10 ** 6 && amountIn < 10 ** 30);

        maatVault.setFees(feeIn, 0);

        uint initialTokenBalanceVault = token.balanceOf(address(maatVault));
        uint initialSharesBalanceBuyer = maatVault.balanceOf(buyer);

        vm.startPrank(buyer);
        token.approve(address(maatVault), amountIn);
        maatVault.deposit(amountIn, buyer);

        uint predictedShares = (maatVault.convertToShares(amountIn) *
            (10 ** 8 - feeIn)) / 10 ** 8;
        // console.log(predictedShares);

        vm.assertApproxEqAbs(
            maatVault.balanceOf(buyer),
            predictedShares + initialSharesBalanceBuyer,
            10
        );
        vm.assertApproxEqAbs(
            maatVault.balanceOf(feeTo),
            maatVault.convertToShares(amountIn) - predictedShares,
            10
        );
        vm.assertEq(
            token.balanceOf(address(maatVault)),
            amountIn + initialTokenBalanceVault
        );
    }

    function testFuzzing_FeeMint(uint shares, uint64 feeIn) public {
        vm.assume(feeIn > 10 ** 6 && feeIn < 5 * 10 ** 6);
        vm.assume(shares > 10 ** 6 && shares < 10 ** 30);

        maatVault.setFees(feeIn, 0);

        uint initialTokenBalanceVault = token.balanceOf(address(maatVault));
        uint initialSharesBalanceBuyer = maatVault.balanceOf(buyer);

        vm.startPrank(buyer);
        token.approve(address(maatVault), shares);
        maatVault.mint(shares, buyer);

        uint predictedShares = (shares * (10 ** 8 - feeIn)) / 10 ** 8;

        vm.assertApproxEqAbs(
            maatVault.balanceOf(buyer),
            predictedShares + initialSharesBalanceBuyer,
            10
        );
        vm.assertApproxEqAbs(
            maatVault.balanceOf(feeTo),
            shares - predictedShares,
            10
        );
        vm.assertEq(
            token.balanceOf(address(maatVault)),
            maatVault.convertToAssets(shares) + initialTokenBalanceVault
        );
    }

    function testFuzzing_FeeWithdraw(uint assets, uint64 feeOut) public {
        vm.assume(feeOut > 10 ** 6 && feeOut < 5 * 10 ** 6);
        vm.assume(assets > 10 ** 6 && assets < 10 ** 30);

        maatVault.setFees(0, feeOut);

        uint initialSharesBalanceBuyer = maatVault.balanceOf(buyer);
        uint initialTokenBalanceBuyer = token.balanceOf(buyer);

        vm.startPrank(buyer);
        maatVault.approve(address(maatVault), 10 ** 50);
        maatVault.withdraw(assets, buyer, buyer);

        uint predictedShares = maatVault.previewWithdraw(assets);

        vm.assertEq(
            maatVault.balanceOf(buyer),
            initialSharesBalanceBuyer - predictedShares
        );
        vm.assertEq(
            maatVault.balanceOf(feeTo),
            maatVault.calculateFee(
                maatVault.convertToSharesByLowerPPS(assets),
                feeOut
            )
        );

        vm.assertApproxEqAbs(
            token.balanceOf(buyer),
            initialTokenBalanceBuyer + assets,
            10
        );
    }

    function testFuzzing_FeeRedeem(uint shares, uint64 feeOut) public {
        vm.assume(feeOut > 10 ** 6 && feeOut < 5 * 10 ** 6);
        vm.assume(shares > 10 ** 6 && shares < 10 ** 30);

        maatVault.setFees(0, feeOut);

        uint initialTokenBalanceBuyer = token.balanceOf(buyer);
        uint initialSharesBalanceBuyer = maatVault.balanceOf(buyer);

        vm.startPrank(buyer);
        maatVault.approve(address(maatVault), 10 ** 50);
        maatVault.redeem(shares, buyer, buyer);

        uint predictedAssets = maatVault.previewRedeem(shares);

        vm.assertEq(
            maatVault.balanceOf(buyer),
            initialSharesBalanceBuyer - shares
        );
        vm.assertEq(
            maatVault.balanceOf(feeTo),
            maatVault.calculateFee(shares, feeOut)
        );
        vm.assertApproxEqAbs(
            token.balanceOf(buyer),
            initialTokenBalanceBuyer + predictedAssets,
            10
        );
    }

    function testFuzzing_FeeRequestWithdraw(uint shares, uint64 feeOut) public {
        uint initialTokenBalanceBuyer = token.balanceOf(buyer);
        uint initialSharesBalanceBuyer = maatVault.balanceOf(buyer);

        vm.assume(
            maatVault.convertToAssetsByLowerPPS(shares) > amountMin &&
                shares < initialSharesBalanceBuyer
        );
        vm.assume(feeOut > 10 ** 6 && feeOut < 5 * 10 ** 6);

        maatVault.setFees(0, feeOut);

        vm.startPrank(buyer);
        uint assets = maatVault.previewRedeem(shares);

        maatVault.approve(address(maatVault), shares);

        bytes32 intentionId = maatVault.requestWithdraw(
            shares,
            1,
            buyer,
            buyer
        );
        vm.stopPrank();

        assertEq(
            maatVault.balanceOf(buyer),
            initialSharesBalanceBuyer - shares
        );

        IExecutor.ActionType fulfillWithdrawRequest = IExecutor
            .ActionType
            .FULFILL_WITHDRAW_REQUEST;

        IExecutor.ActionType[] memory actions = new IExecutor.ActionType[](1);
        actions[0] = fulfillWithdrawRequest;

        IExecutor.ActionInput[] memory actionData = new IExecutor.ActionInput[](
            1
        );

        actionData[0] = IExecutor.ActionInput({
            dstEid: 0,
            strategyId: bytes32(0),
            amount: 0,
            intentionId: intentionId
        });

        maatVault.execute(actions, actionData);

        assertEq(token.balanceOf(buyer), initialTokenBalanceBuyer + assets);
        assertEq(
            maatVault.balanceOf(feeTo),
            maatVault.calculateFee(shares, feeOut)
        );
    }

    function testFuzzing_FeePreviewDeposit(uint assets, uint64 feeIn) public {
        vm.assume(feeIn > 10 ** 6 && feeIn < 5 * 10 ** 6);
        vm.assume(assets > 10 ** 4 && assets < 10 ** 30);

        maatVault.setFees(feeIn, 0);

        uint shares = maatVault.previewDeposit(assets);
        uint predictedShares = maatVault.convertToShares(assets) -
            maatVault.calculateFee(maatVault.convertToShares(assets), feeIn);

        assertEq(shares, predictedShares);
    }

    function testFuzzing_FeePreviewMint(uint shares, uint64 feeIn) public {
        vm.assume(feeIn > 10 ** 6 && feeIn < 5 * 10 ** 6);
        vm.assume(shares > 10 ** 4 && shares < 10 ** 30);

        maatVault.setFees(feeIn, feeIn);

        uint assets = maatVault.previewMint(shares);
        uint predictedAssets = maatVault.convertToAssets(
            shares + maatVault.calculateFee(shares, feeIn)
        );

        assertEq(assets, predictedAssets);
    }

    function testFuzzing_FeePreviewWithdraw(uint assets, uint64 feeOut) public {
        vm.assume(feeOut > 10 ** 6 && feeOut < 5 * 10 ** 6);
        vm.assume(assets > 10 ** 4 && assets < 10 ** 30);

        maatVault.setFees(0, feeOut);

        uint shares = maatVault.previewWithdraw(assets);

        uint predictedShares = maatVault.convertToSharesByLowerPPS(assets) +
            maatVault.calculateFee(
                maatVault.convertToSharesByLowerPPS(assets),
                feeOut
            );

        assertEq(shares, predictedShares);
    }

    function testFuzzing_FeePreviewRedeem(uint shares, uint64 feeOut) public {
        vm.assume(feeOut > 10 ** 6 && feeOut < 5 * 10 ** 6);
        vm.assume(shares > 10 ** 4 && shares < 10 ** 30);

        maatVault.setFees(0, feeOut);

        uint assets = maatVault.previewRedeem(shares);

        uint predictedAssets = maatVault.convertToAssetsByLowerPPS(
            shares - maatVault.calculateFee(shares, feeOut)
        );

        assertEq(assets, predictedAssets);
    }
}
