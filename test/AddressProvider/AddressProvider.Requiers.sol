// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {MaatAddressProviderTestSetup, MaatAddressProviderV1} from "./_AddressProvider.Setup.sol";

contract AddressProviderSettersFuncTesting is MaatAddressProviderTestSetup {
    function test_AddStrategy_StrategyAlreadyAdded() public {
        address strategy = address(strategyUSDC);

        vm.startPrank(admin);
        maatAddressProvider.addStrategy(strategy);

        vm.expectRevert(MaatAddressProviderV1.AlreadyAdded.selector);
        maatAddressProvider.addStrategy(strategy);
    }

    function test_RemoveStrategy_StrategyNotAddedYet() public {
        address strategy = address(strategyUSDC);

        vm.startPrank(admin);
        vm.expectRevert(MaatAddressProviderV1.NotAdded.selector);
        maatAddressProvider.removeStrategy(strategy);
    }

    function test_AddVault_VaultAlreadyAdded() public {
        address vault = address(MaatVaultUSDC);

        vm.startPrank(admin);
        maatAddressProvider.addVault(vault);

        vm.expectRevert(MaatAddressProviderV1.AlreadyAdded.selector);
        maatAddressProvider.addVault(vault);
    }

    function test_RemoveVault_VaultNotAddedYet() public {
        address vault = address(MaatVaultUSDC);

        vm.startPrank(admin);
        vm.expectRevert(MaatAddressProviderV1.NotAdded.selector);
        maatAddressProvider.removeVault(vault);
    }
}
