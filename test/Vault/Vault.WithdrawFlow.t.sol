// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";
import {StargateAdapterMock} from "../mock/StargateAdapterMock.sol";

contract MaatVaultWithdrawFlowTesting is MaatVaultTestSetup {
    address owner = address(0x12854888);
    address receiver = address(0xdddd);

    uint initialBalanceShares = 10 ** 40;
    uint initialBalanceToken = 10 ** 40;

    StargateAdapterMock stargateAdapter;
    MaatVaultHarness secondMaatVault;

    function _afterSetUp() internal override {
        stargateAdapter = new StargateAdapterMock();
        addressProvider.changeStargateAdapter(address(stargateAdapter));

        secondMaatVault = new MaatVaultHarness(
            address(this),
            address(token),
            amountMin,
            address(addressProvider),
            commander,
            watcher,
            2
        );

        uint32[] memory eids = new uint32[](1);
        eids[0] = 2;

        address[] memory vaults = new address[](1);
        vaults[0] = address(secondMaatVault);

        maatVault.addRelatedVaults(eids, vaults);
        stargateAdapter.setPeer(2, address(secondMaatVault));
        deal(address(token), owner, initialBalanceToken * 2);
        deal(address(token), address(maatVault), initialBalanceToken);

        vm.startPrank(owner);
        token.approve(address(maatVault), initialBalanceShares * 2);
        maatVault.mint(initialBalanceShares, owner);
        vm.stopPrank();

        address[] memory vaultsArray = new address[](1);
        vaultsArray[0] = address(maatVault);

        uint112[] memory ppsArray = new uint112[](1);
        ppsArray[0] = 132123123;

        skip(10);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);
        skip(10);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);
    }

    function testFuzzing_RequestWithdraw_CreatingRequest(
        uint sharesToWithdraw
    ) public {
        vm.assume(sharesToWithdraw <= 10 ** 40);
        vm.assume(sharesToWithdraw > amountMin);

        vm.startPrank(owner);
        maatVault.approve(address(maatVault), sharesToWithdraw);

        maatVault.setNonce(0);
        vm.expectEmit(address(maatVault));
        emit IWithdrawRequestLogic.WithdrawalRequested(
            sharesToWithdraw,
            maatVault.previewRedeem(sharesToWithdraw),
            owner,
            maatVault.getIntentionId(0),
            1
        );
        bytes32 intentionId = maatVault.requestWithdraw(
            sharesToWithdraw,
            1,
            owner,
            receiver
        );

        IMaatVaultV1.WithdrawRequestInfo memory request = maatVault
            .getWithdrawRequest(intentionId);

        assertEq(request.owner, owner, "Owner address failed");
        assertEq(request.receiver, receiver, "Receiver address failed");
        assertEq(request.dstEid, 1, "dstEid Failed");
        assertEq(request.creationTime, block.timestamp, "Creation time failed");
        assertEq(request.shares, sharesToWithdraw, "Amount of shares failed");

        assertEq(
            maatVault.balanceOf(address(maatVault)),
            sharesToWithdraw,
            "Balance of shares on MaatVaultV1 failed"
        );

        assertEq(
            maatVault.balanceOf(owner),
            initialBalanceShares - sharesToWithdraw,
            "Balance of shares of owner failed"
        );
    }

    function test_RequestWithdraw_RevertIf_ChainIsNotSupported() public {
        uint sharesToWithdraw = 10 ** 6;
        vm.startPrank(owner);
        maatVault.approve(address(maatVault), sharesToWithdraw);

        vm.expectRevert("MaatVaultV1: Chain is not supported for withdrawal");
        maatVault.requestWithdraw(sharesToWithdraw, 12, owner, receiver);
    }

    function test_RequestWithdraw_RevertIf_ReceiverIsZeroAddress() public {
        uint sharesToWithdraw = 10 ** 6;
        vm.startPrank(owner);
        maatVault.approve(address(maatVault), sharesToWithdraw);

        vm.expectRevert("WithdrawRequestLogic: Receiver is zero address");
        maatVault.requestWithdraw(sharesToWithdraw, 1, owner, address(0));
    }

    function test_RequestWithdraw_RevertIf_AmountIsLessThatMinAmount() public {
        uint sharesToWithdraw = 10;
        vm.startPrank(owner);
        maatVault.approve(address(maatVault), sharesToWithdraw);

        vm.expectRevert(Vault.AmountIsTooLow.selector);
        maatVault.requestWithdraw(sharesToWithdraw, 1, owner, address(0));
    }

    function test_RequestWithdraw_RevertIf_SenderIsNotOwner() public {
        uint assets = 10 ** 10;
        owner = address(0x123456);
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
        maatVault.requestWithdraw(assets, 1, owner, owner);
    }

    function test_FulfillWithdrawRequest_WithoutBridge() public {
        uint sharesToWithdraw = 10 ** 10;
        vm.startPrank(owner);

        maatVault.approve(address(maatVault), sharesToWithdraw);

        bytes32 intentionId = maatVault.requestWithdraw(
            sharesToWithdraw,
            1,
            owner,
            receiver
        );

        vm.stopPrank();

        vm.startPrank(commander);

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
        uint totalSupplyBefore = maatVault.totalSupply();
        uint balanceReceiverBefore = token.balanceOf(receiver);
        uint predictedAmountOut = maatVault.previewRedeem(sharesToWithdraw);

        maatVault.execute(actions, actionData);

        uint totalSupplyAfter = maatVault.totalSupply();

        assertTrue(
            totalSupplyAfter < totalSupplyBefore,
            "Total supply assertion failed"
        );
        assertEq(
            balanceReceiverBefore + predictedAmountOut,
            token.balanceOf(receiver),
            "Tokens are not delivered"
        );

        vm.expectRevert("MaatVaultV1: Request not found");
        IMaatVaultV1.WithdrawRequestInfo memory request = maatVault
            .getWithdrawRequest(intentionId);
    }

    function test_FulfillWithdrawRequest_WithBridge() public {
        uint sharesToWithdraw = 10 ** 10;
        vm.startPrank(owner);

        maatVault.approve(address(maatVault), sharesToWithdraw);

        bytes32 intentionId = maatVault.requestWithdraw(
            sharesToWithdraw,
            2,
            owner,
            receiver
        );

        vm.stopPrank();

        vm.startPrank(commander);

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
        uint totalSupplyBefore = maatVault.totalSupply();
        uint balanceReceiverBefore = token.balanceOf(receiver);
        uint predictedAmountOut = maatVault.previewRedeem(sharesToWithdraw);

        uint idleBefore = maatVault.idle();
        maatVault.execute(actions, actionData);

        uint totalSupplyAfter = maatVault.totalSupply();

        assertTrue(
            totalSupplyAfter < totalSupplyBefore,
            "Total supply assertion failed"
        );
        assertEq(
            balanceReceiverBefore + predictedAmountOut,
            token.balanceOf(receiver),
            "Tokens are not delivered"
        );

        assertEq(idleBefore - predictedAmountOut, maatVault.idle());

        vm.expectRevert("MaatVaultV1: Request not found");
        IMaatVaultV1.WithdrawRequestInfo memory request = maatVault
            .getWithdrawRequest(intentionId);
    }
}
