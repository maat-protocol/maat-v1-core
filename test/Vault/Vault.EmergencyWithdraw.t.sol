// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";
import {StargateAdapterMock} from "../mock/StargateAdapterMock.sol";

contract VaultEmergencyWithdrawalTest is MaatVaultTestSetup {
    address owner = address(0x12854888);
    address receiver = address(0xdddd);

    uint initialBalanceShares = 975902173542;
    uint initialBalanceToken = 10 ** 40;

    StargateAdapterMock stargateAdapter;
    MaatVaultHarness secondMaatVault;

    function _afterSetUp() internal override {
        maatVault.setIdle(0);
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
        maatVault.depositInStrategy(
            strategyId,
            maatVault.idle(),
            bytes32("intentionId")
        );
        vm.stopPrank();
    }

    function testFuzzing_EmergencyWithdraw_SingleChain(
        uint256 sharesWithdrawRequest
    ) public {
        vm.assume(sharesWithdrawRequest <= initialBalanceShares);
        vm.assume(sharesWithdrawRequest > maatVault.minAmount());

        vm.assertEq(maatVault.idle(), 0);

        (
            IExecutor.ActionInput[] memory withdrawInputs,
            uint256 amountOutTokens
        ) = _makeActionInput(1, sharesWithdrawRequest);

        _emergencyWithdraw_template(
            sharesWithdrawRequest,
            maatVault.chainEid(),
            owner,
            receiver,
            withdrawInputs,
            amountOutTokens,
            false
        );
    }

    function testFuzzing_EmergencyWithdraw_CrossChain(
        uint256 sharesWithdrawRequest
    ) public {
        vm.assume(sharesWithdrawRequest <= initialBalanceShares);
        vm.assume(sharesWithdrawRequest > maatVault.minAmount());

        (
            IExecutor.ActionInput[] memory withdrawInputs,
            uint256 amountOutTokens
        ) = _makeActionInput(1, sharesWithdrawRequest);

        _emergencyWithdraw_template(
            sharesWithdrawRequest,
            secondMaatVault.chainEid(),
            owner,
            receiver,
            withdrawInputs,
            amountOutTokens,
            false
        );
    }

    function testFuzzing_EmergencyWithdraw_SeveralActions(
        uint256 sharesWithdrawRequest
    ) public {
        vm.assume(sharesWithdrawRequest <= initialBalanceShares);
        vm.assume(sharesWithdrawRequest > maatVault.minAmount());
        vm.assume(sharesWithdrawRequest > 1e6);

        (
            IExecutor.ActionInput[] memory withdrawInputs,
            uint256 amountOutTokens
        ) = _makeActionInput(10, sharesWithdrawRequest);

        _emergencyWithdraw_template(
            sharesWithdrawRequest,
            maatVault.chainEid(),
            owner,
            receiver,
            withdrawInputs,
            amountOutTokens,
            false
        );
    }

    function test_EmergencyWithdraw_TooMuchWithdrawn() public {
        uint256 amountToWithdraw = initialBalanceShares / 2;

        (
            IExecutor.ActionInput[] memory withdrawInputs,
            uint256 amountOutTokens
        ) = _makeActionInput(1, (amountToWithdraw * 110) / 100);

        _emergencyWithdraw_template(
            amountToWithdraw,
            maatVault.chainEid(),
            owner,
            receiver,
            withdrawInputs,
            amountOutTokens,
            true
        );
    }

    function test_EmergencyWithdraw_EarlyWithdrawal() public {
        vm.startPrank(owner);

        maatVault.approve(address(maatVault), initialBalanceShares / 2);
        bytes32 intentionId = maatVault.requestWithdraw(
            initialBalanceShares / 2,
            maatVault.chainEid(),
            owner,
            receiver
        );

        vm.expectRevert();
        maatVault.emergencyWithdraw(
            intentionId,
            new IExecutor.ActionInput[](0)
        );
    }

    function _makeActionInput(
        uint256 _withdrawAmount,
        uint256 _sharesWithdrawRequest
    )
        internal
        view
        returns (
            IExecutor.ActionInput[] memory withdrawInputs,
            uint256 amountOutTokens
        )
    {
        withdrawInputs = new IExecutor.ActionInput[](_withdrawAmount);

        amountOutTokens = maatVault.convertToAssetsByLowerPPS(
            _sharesWithdrawRequest
        );

        for (uint256 i = 0; i < _withdrawAmount; i++) {
            withdrawInputs[i] = IExecutor.ActionInput({
                intentionId: bytes32(0),
                dstEid: 0,
                strategyId: strategyId,
                amount: amountOutTokens / _withdrawAmount + 1
            });
        }
    }

    function _emergencyWithdraw_template(
        uint256 _sharesWithdrawRequest,
        uint32 _chainEidToWithdraw,
        address _owner,
        address _receiver,
        IExecutor.ActionInput[] memory _withdrawInputs,
        uint256 _amountOutTokens,
        bool _shouldRevert
    ) internal {
        uint256 _initialBalanceReceiver = token.balanceOf(_receiver);
        uint256 _sharesInitialBalanceOwner = maatVault.balanceOf(_owner);

        vm.startPrank(_owner);

        maatVault.approve(address(maatVault), _sharesWithdrawRequest);
        bytes32 intentionId = maatVault.requestWithdraw(
            _sharesWithdrawRequest,
            _chainEidToWithdraw,
            _owner,
            _receiver
        );

        vm.warp(block.timestamp + maatVault.emergencyWithdrawalDelay());

        if (_shouldRevert) vm.expectRevert();

        maatVault.emergencyWithdraw(intentionId, _withdrawInputs);

        if (_shouldRevert) return;

        assertEq(
            token.balanceOf(_receiver),
            _initialBalanceReceiver + _amountOutTokens
        );
        assertEq(
            maatVault.balanceOf(_owner),
            _sharesInitialBalanceOwner - _sharesWithdrawRequest
        );

        vm.expectRevert();
        maatVault.getWithdrawRequest(intentionId);
    }
}
