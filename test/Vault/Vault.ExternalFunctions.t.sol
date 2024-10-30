// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";

contract MaatVaultExternalFunctionsTesting is MaatVaultTestSetup {
    Strategy secondStrategy;

    address public yearnVaultAddr = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1;
    address public USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    bytes32 secondStrategyId;

    function _afterSetUp() internal override {
        IStrategyFromStrategies.StrategyParams
            memory strategyParams = IStrategyFromStrategies.StrategyParams(
                chainId,
                "YEARN",
                3,
                USDT,
                yearnUSDTVault
            );

        secondStrategy = Strategy(
            address(
                new YearnV3Strategy(
                    strategyParams,
                    address(addressProvider),
                    feeToPerformance,
                    performanceFee
                )
            )
        );
        secondStrategyId = secondStrategy.getStrategyId();

        addressProvider.addStrategy(address(secondStrategy));

        maatVault.addStrategy(address(secondStrategy));
    }

    function testFuzzingDepositFunction(uint assets) public {
        vm.assume(assets <= strategy.maxDeposit(address(maatVault)));
        vm.assume(assets < 10 ** 60);
        vm.assume(assets > amountMin);

        //initialPPS = 1
        address user = address(0x123456);

        deal(address(token), address(this), assets);

        uint256 balance = token.balanceOf(address(maatVault));

        token.approve(address(maatVault), assets);
        uint shares = maatVault.deposit(assets, user);
        vm.stopPrank();

        assertEq(token.balanceOf(address(maatVault)), balance + assets);
        assertEq(maatVault.balanceOf(user), assets);
        assertEq(shares, maatVault.previewDeposit(assets));
    }

    function testFuzzingMintFunction(uint shares) public {
        vm.assume(shares < 10 ** 60);
        vm.assume(shares > amountMin);

        address user = address(0x123456);

        deal(address(token), address(this), shares);

        uint256 balance = token.balanceOf(address(maatVault));

        token.approve(address(maatVault), shares);
        uint assets = maatVault.mint(shares, user);
        vm.stopPrank();

        assertEq(assets, maatVault.previewMint(shares));
        assertEq(token.balanceOf(address(maatVault)), balance + shares);
        assertEq(maatVault.balanceOf(user), shares);
    }

    function testFuzzing_WithdrawFunction(uint assets) public {
        vm.assume(assets < 10 ** 60);
        vm.assume(assets > amountMin);
        address user = address(0x123456);

        deal(address(token), address(user), assets);

        uint256 balance = token.balanceOf(address(maatVault));

        vm.startPrank(user);
        token.approve(address(maatVault), assets);
        uint shares = maatVault.deposit(assets, user);

        assertEq(token.balanceOf(address(maatVault)), balance + assets);
        assertEq(maatVault.balanceOf(user), maatVault.convertToShares(assets));

        balance = token.balanceOf(address(maatVault));

        maatVault.approve(address(maatVault), shares);
        uint sharesToWithdraw = maatVault.withdraw(assets, user, user);

        assertEq(sharesToWithdraw, maatVault.previewWithdraw(assets));
        assertEq(token.balanceOf(address(maatVault)), balance - assets);
        assertEq(maatVault.balanceOf(user), 0);
    }

    function test_Withdraw_RevertIf_SenderIsNotOwner() public {
        uint assets = 10 ** 10;
        address owner = address(0x123456);
        address notowner = address(0x1234567);

        deal(address(token), address(owner), assets);

        uint256 balance = token.balanceOf(address(maatVault));

        vm.startPrank(owner);
        token.approve(address(maatVault), assets);
        uint shares = maatVault.deposit(assets, owner);
        balance = token.balanceOf(address(maatVault));

        maatVault.approve(address(maatVault), shares);
        vm.stopPrank();

        vm.prank(notowner);
        vm.expectRevert(
            abi.encodeWithSelector(Vault.UnauthorizedUser.selector, notowner)
        );
        maatVault.withdraw(assets, owner, owner);
    }

    function testFuzzing_RedeemFunction(uint shares) public {
        vm.assume(shares < 10 ** 60);
        vm.assume(shares > amountMin);

        address user = address(0x123456);

        deal(address(token), address(this), shares);

        uint256 balance = token.balanceOf(address(maatVault));

        token.approve(address(maatVault), shares);
        maatVault.mint(shares, user);
        vm.stopPrank();

        assertEq(token.balanceOf(address(maatVault)), balance + shares);
        assertEq(maatVault.balanceOf(user), shares);

        balance = token.balanceOf(address(maatVault));

        vm.startPrank(user);
        maatVault.approve(address(maatVault), shares);
        uint assets = maatVault.redeem(shares, user, user);

        assertEq(assets, maatVault.previewRedeem(shares));
        assertEq(token.balanceOf(address(maatVault)), balance - shares);
        assertEq(maatVault.balanceOf(user), 0);
    }

    function test_Redeem_RevertIf_SenderIsNotOwner() public {
        uint shares = 10 ** 10;
        address owner = address(0x123456);
        address notowner = address(0x1234567);

        deal(address(token), address(owner), shares);

        uint256 balance = token.balanceOf(address(maatVault));

        vm.startPrank(owner);
        token.approve(address(maatVault), shares);
        maatVault.deposit(shares, owner);
        balance = token.balanceOf(address(maatVault));

        maatVault.approve(address(maatVault), shares);
        vm.stopPrank();

        vm.prank(notowner);
        vm.expectRevert(
            abi.encodeWithSelector(Vault.UnauthorizedUser.selector, notowner)
        );
        maatVault.redeem(shares, owner, owner);
    }

    function testFuzzingExecution(
        uint _amountInFirst,
        uint _amountOutFirst,
        uint _amountInSecond,
        uint _amountOutSecond
    ) public {
        vm.assume(_amountInFirst < type(uint).max / 2);
        vm.assume(_amountInSecond < type(uint).max / 2);

        uint depositLimit = strategy.maxDeposit(address(maatVault));

        vm.assume(_amountInFirst + _amountInSecond < depositLimit);
        vm.assume(
            _amountInFirst < 10 ** 50 && _amountOutFirst < _amountInFirst
        );
        vm.assume(
            _amountInSecond < 10 ** 50 && _amountOutSecond < _amountInSecond
        );
        vm.assume(_amountOutFirst > 0 && _amountOutSecond > 0);

        deal(
            address(token),
            address(maatVault),
            _amountInFirst + _amountInSecond
        );

        IExecutor.ActionType deposit = IExecutor.ActionType.DEPOSIT;
        IExecutor.ActionType withdraw = IExecutor.ActionType.WITHDRAW;

        IExecutor.ActionType[] memory actions = new IExecutor.ActionType[](4);
        actions[0] = deposit;
        actions[1] = withdraw;
        actions[2] = deposit;
        actions[3] = withdraw;

        IExecutor.ActionInput[] memory actionData = new IExecutor.ActionInput[](
            4
        );

        actionData[0] = IExecutor.ActionInput({
            dstEid: 0,
            strategyId: strategyId,
            amount: _amountInFirst,
            intentionId: bytes32(0)
        });
        actionData[1] = IExecutor.ActionInput({
            dstEid: 0,
            strategyId: strategyId,
            amount: _amountOutFirst,
            intentionId: bytes32(0)
        });

        actionData[2] = IExecutor.ActionInput({
            dstEid: 0,
            strategyId: secondStrategyId,
            amount: _amountInSecond,
            intentionId: bytes32(0)
        });
        actionData[3] = IExecutor.ActionInput({
            dstEid: 0,
            strategyId: secondStrategyId,
            amount: _amountOutSecond,
            intentionId: bytes32(0)
        });

        uint balance = token.balanceOf(address(maatVault));

        vm.prank(address(commander));
        maatVault.execute(actions, actionData);

        assertEq(
            token.balanceOf(address(maatVault)),
            balance -
                (_amountInFirst + _amountInSecond) +
                (_amountOutFirst + _amountOutSecond)
        );

        uint maxLoss = 5 wei;
        uint assets = strategy.maxWithdraw(address(maatVault));
        uint diff = _amountInFirst - _amountOutFirst;

        assertApproxEqAbs(
            assets,
            diff,
            maxLoss,
            "First Deposit&Withdraw calculation error resulted in more then 2 wei"
        );

        assets = secondStrategy.maxWithdraw(address(maatVault));
        diff = _amountInSecond - _amountOutSecond;

        assertApproxEqAbs(
            assets,
            diff,
            maxLoss,
            "Second Deposit&Withdraw calculation error resulted in more then 2 wei"
        );
    }

    function test_DepositWhen_ReceiverIsNotSender() public {
        address receiver = address(0x1306);
        address buyer = address(0x123798);

        deal(address(token), buyer, 10 ** 18);

        uint amountToDeposit = 10 ** 10;

        vm.startPrank(buyer);
        token.approve(address(maatVault), amountToDeposit);

        maatVault.deposit(amountToDeposit, receiver);
        vm.stopPrank();

        assertEq(maatVault.balanceOf(receiver), amountToDeposit);
        assertEq(token.balanceOf(buyer), 10 ** 18 - amountToDeposit);
        assertEq(token.balanceOf(address(maatVault)), amountToDeposit);
    }

    function testFuzzing_Deposit_WithCustomPPS(uint assets) public {
        uint112 pps = 232332112;

        address receiver = address(0x1306);
        address buyer = address(0x123798);

        vm.assume(assets > amountMin && assets < (2 ** 112 - 1));

        skip(100);
        address[] memory vaultsArray = new address[](1);
        vaultsArray[0] = address(maatVault);

        uint112[] memory ppsArray = new uint112[](1);
        ppsArray[0] = pps;

        oracle.updateGlobalPPS(vaultsArray, ppsArray);

        deal(address(token), buyer, assets);

        uint predictedShares = (assets * 10 ** 8) / pps;

        vm.startPrank(buyer);
        token.approve(address(maatVault), assets);

        maatVault.deposit(assets, receiver);
        vm.stopPrank();

        assertEq(
            maatVault.balanceOf(receiver),
            predictedShares,
            "Shares is not correct"
        );
        assertEq(token.balanceOf(buyer), 0);
        assertEq(token.balanceOf(address(maatVault)), assets);
    }

    function testFuzzing_Withdraw_WithCustomPPS(uint shares) public {
        uint112 pps = 232332112;

        address receiver = address(0x1306);
        address owner = address(0x123798);

        vm.assume(shares > amountMin && shares < (2 ** 112 - 1));

        address[] memory vaultsArray = new address[](1);
        vaultsArray[0] = address(maatVault);

        uint112[] memory ppsArray = new uint112[](1);
        ppsArray[0] = pps;

        skip(100);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);
        skip(100);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);

        uint predictedAmountOut = (shares * pps) / 10 ** 8;

        deal(address(maatVault), owner, shares);
        deal(address(token), address(maatVault), predictedAmountOut + 10);

        vm.startPrank(owner);
        maatVault.approve(address(maatVault), shares);

        uint balanceBefore = token.balanceOf(address(maatVault));

        maatVault.redeem(shares, receiver, owner);

        assertEq(maatVault.balanceOf(owner), 0, "Shares is not correct");
        assertEq(token.balanceOf(owner), 0);
        assertEq(
            token.balanceOf(address(maatVault)),
            balanceBefore - predictedAmountOut
        );
        assertEq(token.balanceOf(address(receiver)), predictedAmountOut);
    }

    function test_Deposit_RevertIf_AmountLessThanMinAmount() public {
        address buyer = address(0x123798);

        deal(address(token), buyer, 10 ** 18);

        uint amountToDeposit = amountMin - 1;

        vm.startPrank(buyer);
        token.approve(address(maatVault), amountToDeposit);

        vm.expectRevert(Vault.AmountIsTooLow.selector);
        maatVault.deposit(amountToDeposit, buyer);

        vm.stopPrank();

        assertEq(maatVault.balanceOf(buyer), 0);
    }

    function test_Rebalance() public {
        vm.expectEmit(address(maatVault));
        bytes32 expectedIntentionId = maatVault.getIntentionId(0);

        emit IExecutor.RebalanceRequested(expectedIntentionId, "extraData");
        maatVault.requestRebalance("extraData");
    }
}
