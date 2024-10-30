// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {MaatAddressProviderTestSetup, MaatAddressProviderV1} from "./_AddressProvider.Setup.sol";

contract AddressProviderSettersFuncTesting is MaatAddressProviderTestSetup {
    function test_AddStrategy_OnlyOwner() public {
        address strategy = address(strategyUSDC);

        vm.expectRevert(MaatAddressProviderV1.NotAdmin.selector);
        maatAddressProvider.addStrategy(strategy);
    }

    function test_RemoveStrategy_OnlyOwner() public {
        address strategy = address(strategyUSDC);

        vm.expectRevert(MaatAddressProviderV1.NotAdmin.selector);
        maatAddressProvider.removeStrategy(strategy);
    }

    function test_AddVault_OnlyOwner() public {
        address vault = address(MaatVaultUSDC);

        vm.expectRevert(MaatAddressProviderV1.NotAdmin.selector);
        maatAddressProvider.addVault(vault);
    }

    function test_RemoveVault_OnlyOwner() public {
        address vault = address(MaatVaultUSDC);

        vm.expectRevert(MaatAddressProviderV1.NotAdmin.selector);
        maatAddressProvider.addVault(vault);
    }

    function test_ChangeOracle() public {
        vm.expectRevert(MaatAddressProviderV1.NotAdmin.selector);
        maatAddressProvider.changeOracle(address(0));
    }

    function test_ChangeIncentiveController() public {
        vm.expectRevert(MaatAddressProviderV1.NotAdmin.selector);
        maatAddressProvider.changeIncentiveController(address(0));
    }

    function test_ChangeAdmin() public {
        vm.expectRevert(MaatAddressProviderV1.NotAdmin.selector);
        maatAddressProvider.changeAdmin(address(0));
    }
}
