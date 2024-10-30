// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";

contract MaatVaultNonceTesting is MaatVaultTestSetup {
    address owner = address(0x12854888);
    address receiver = address(0xdddd);

    uint initialBalanceShares = 10 ** 40;
    uint initialBalanceToken = 10 ** 40;

    MaatVaultHarness secondMaatVault;

    function _afterSetUp() internal override {
        secondMaatVault = new MaatVaultHarness(
            address(this),
            address(token),
            amountMin,
            address(addressProvider),
            commander,
            watcher,
            1
        );

        addressProvider.addVault(address(secondMaatVault));

        oracle.initPPS(address(secondMaatVault), initialPPS, initialPPS);

        uint32[] memory eids = new uint32[](1);
        eids[0] = 2;

        address[] memory vaults = new address[](1);
        vaults[0] = address(secondMaatVault);

        maatVault.addRelatedVaults(eids, vaults);
        deal(address(token), owner, initialBalanceToken * 2);
        deal(address(token), address(maatVault), initialBalanceToken);

        vm.startPrank(owner);
        token.approve(address(maatVault), initialBalanceShares * 2);
        maatVault.mint(initialBalanceShares, owner);
        vm.stopPrank();

        deal(address(token), owner, initialBalanceToken * 2);
        deal(address(token), address(secondMaatVault), initialBalanceToken);

        vm.startPrank(owner);
        token.approve(address(secondMaatVault), initialBalanceShares * 2);
        secondMaatVault.mint(initialBalanceShares, owner);
        vm.stopPrank();

        address[] memory vaultsArray = new address[](2);
        vaultsArray[0] = address(maatVault);
        vaultsArray[1] = address(secondMaatVault);

        uint112[] memory ppsArray = new uint112[](2);
        ppsArray[0] = 132123123;
        ppsArray[1] = 132123123;

        skip(10);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);
        skip(10);
        oracle.updateGlobalPPS(vaultsArray, ppsArray);
    }

    function test_IntentionIsDifferentOnEachRequest() public {
        uint sharesToWithdraw = 10 ** 10;

        vm.startPrank(owner);
        maatVault.approve(address(maatVault), 10 * sharesToWithdraw);

        bytes32 intentionId1 = maatVault.requestWithdraw(
            sharesToWithdraw,
            1,
            owner,
            receiver
        );

        bytes32 intentionId2 = maatVault.requestWithdraw(
            sharesToWithdraw,
            1,
            owner,
            receiver
        );

        assertFalse(intentionId1 == intentionId2);
    }

    function test_IntentionIdIsDifferentOnEachVault() public {
        uint sharesToWithdraw = 10 ** 10;

        vm.startPrank(owner);
        maatVault.approve(address(maatVault), 10 * sharesToWithdraw);
        secondMaatVault.approve(
            address(secondMaatVault),
            10 * sharesToWithdraw
        );

        bytes32 intentionId1 = maatVault.requestWithdraw(
            sharesToWithdraw,
            1,
            owner,
            receiver
        );

        bytes32 intentionId2 = secondMaatVault.requestWithdraw(
            sharesToWithdraw,
            1,
            owner,
            receiver
        );

        assertFalse(intentionId1 == intentionId2);
    }
}
