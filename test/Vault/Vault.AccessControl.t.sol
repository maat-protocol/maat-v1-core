// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";

contract MaatVaultAccessControlTesting is MaatVaultTestSetup {
    function test_AddStrategyOwnable() public {
        address _nonowner = address(0x00000001);
        vm.prank(_nonowner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                _nonowner
            )
        );
        maatVault.addStrategy(address(0x123));
    }

    function test_RemoveStrategyOwnable() public {
        vm.expectRevert();
        vm.prank(address(0x00000001));
        maatVault.removeStrategy(keccak256(abi.encode(address(2))));

        address nonowner = address(0x1237);
        vm.expectRevert();
        vm.prank(nonowner);
        maatVault.removeStrategy(keccak256(abi.encode(address(3))));
    }

    function test_EnableStrategyOwnable() public {
        vm.expectRevert();
        vm.prank(address(0x00000001));
        maatVault.enableStrategy(keccak256(abi.encode(address(2))));

        address nonowner = address(0x1237);
        vm.expectRevert();
        vm.prank(nonowner);
        maatVault.enableStrategy(keccak256(abi.encode(address(3))));
    }

    function test_DisableStrategyOwnable() public {
        vm.expectRevert();
        vm.prank(address(0x00000001));
        maatVault.disableStrategy(keccak256(abi.encode(address(2))));

        address nonowner = address(0x1237);
        vm.expectRevert();
        vm.prank(nonowner);
        maatVault.disableStrategy(keccak256(abi.encode(address(3))));
    }

    function test_ExecuteOwnable() public {
        IExecutor.ActionType[] memory actions = new IExecutor.ActionType[](1);
        actions[0] = IExecutor.ActionType.DEPOSIT;

        IExecutor.ActionInput[] memory actionData = new IExecutor.ActionInput[](
            1
        );

        actionData[0] = IExecutor.ActionInput({
            dstEid: 0,
            strategyId: strategyId,
            amount: 1000,
            intentionId: bytes32(0)
        });

        deal(address(token), address(maatVault), 100000000);

        address nonowner = address(0x1237);
        vm.expectRevert("MaatVaultV1: Caller is not commander or admin");
        vm.prank(nonowner);
        maatVault.execute(actions, actionData);
    }

    function test_SetWithdrawTimer_Ownable() public {
        address nonowner = address(0xdead);
        vm.prank(nonowner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonowner
            )
        );
        maatVault.setWithdrawCancellationDelay(1000);
    }

    function test_Rebalance_OnlyWatcherOrAdmin() public {
        vm.expectRevert("MaatVaultV1: Caller is not watcher or admin");
        vm.prank(commander);
        maatVault.requestRebalance("");
    }
}
