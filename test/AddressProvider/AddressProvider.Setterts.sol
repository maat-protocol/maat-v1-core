// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {MaatAddressProviderTestSetup} from "./_AddressProvider.Setup.sol";
import {MaatAddressProviderV1} from "../../src/periphery/MaatAddressProviderV1.sol";
import {MaatOracleGlobalPPS} from "../../src/periphery/MaatOracleGlobalPPS.sol";

contract AddressProviderSettersFuncTesting is MaatAddressProviderTestSetup {
    function test_AddStrategy() public {
        address strategy = address(strategyUSDC);

        vm.startPrank(admin);
        maatAddressProvider.addStrategy(strategy);

        address[] memory _strategies = maatAddressProvider.getStrategies();
        assertEq(_strategies.length, 1);
        assertEq(_strategies[0], strategy);
        assertEq(maatAddressProvider.isStrategy(strategy), true);
    }

    function test_RemoveStrategy() public {
        address strategy = address(strategyUSDC);

        vm.startPrank(admin);
        maatAddressProvider.addStrategy(strategy);

        address[] memory _strategies = maatAddressProvider.getStrategies();
        assertEq(_strategies.length, 1);

        maatAddressProvider.removeStrategy(strategy);
        _strategies = maatAddressProvider.getStrategies();
        assertEq(_strategies.length, 0);
        assertEq(maatAddressProvider.isStrategy(strategy), false);
    }

    function test_AddVault() public {
        address vault = address(MaatVaultUSDC);

        address[] memory _vaults = maatAddressProvider.getVaults();
        assertEq(_vaults.length, 0);

        vm.startPrank(admin);
        maatAddressProvider.addVault(vault);

        _vaults = maatAddressProvider.getVaults();
        assertEq(_vaults.length, 1);
        assertEq(_vaults[0], vault);
        assertEq(maatAddressProvider.isVault(vault), true);
    }

    function test_RemoveVault() public {
        address vault = address(MaatVaultUSDC);

        address[] memory _vaults = maatAddressProvider.getVaults();
        assertEq(_vaults.length, 0);

        vm.startPrank(admin);
        maatAddressProvider.addVault(vault);

        maatAddressProvider.removeVault(vault);
        _vaults = maatAddressProvider.getVaults();
        assertEq(_vaults.length, 0);
        assertEq(maatAddressProvider.isVault(vault), false);
    }

    function test_AddStrategy_twice() public {
        vm.startPrank(admin);
        maatAddressProvider.addStrategy(address(strategyUSDC));
        maatAddressProvider.addStrategy(address(strategyUSDT));

        address[] memory _strategies = maatAddressProvider.getStrategies();
        assertEq(_strategies.length, 2);
    }

    function test_AddStrategy_RevertIf_InterfaceIsNotSupported() public {
        vm.startPrank(admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                MaatAddressProviderV1.AddressIsNotStrategy.selector,
                address(maatAddressProvider)
            )
        );
        maatAddressProvider.addStrategy(address(maatAddressProvider));
    }

    function test_RemoveStrategy_twice() public {
        vm.startPrank(admin);
        maatAddressProvider.addStrategy(address(strategyUSDC));
        maatAddressProvider.addStrategy(address(strategyUSDT));

        address[] memory _strategies = maatAddressProvider.getStrategies();
        assertEq(_strategies.length, 2);

        maatAddressProvider.removeStrategy(address(strategyUSDT));
        _strategies = maatAddressProvider.getStrategies();
        assertEq(_strategies.length, 1);
    }

    function test_AddVault_twice() public {
        vm.startPrank(admin);
        maatAddressProvider.addVault(address(MaatVaultUSDC));
        maatAddressProvider.addVault(address(MaatVaultUSDT));

        address[] memory _vaults = maatAddressProvider.getVaults();
        assertEq(_vaults.length, 2);
    }

    function test_AddVault_RevertIf_InterfaceIsNotSupported() public {
        vm.startPrank(admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                MaatAddressProviderV1.AddressIsNotMaatVault.selector,
                address(maatAddressProvider)
            )
        );
        maatAddressProvider.addVault(address(maatAddressProvider));
    }

    function test_RemoveVault_twice() public {
        vm.startPrank(admin);
        maatAddressProvider.addVault(address(MaatVaultUSDC));
        maatAddressProvider.addVault(address(MaatVaultUSDT));

        address[] memory _vaults = maatAddressProvider.getVaults();
        assertEq(_vaults.length, 2);

        maatAddressProvider.removeVault(address(MaatVaultUSDC));
        _vaults = maatAddressProvider.getVaults();
        assertEq(_vaults.length, 1);
    }

    function test_ChangeOracle() public {
        MaatOracleGlobalPPS oracle = new MaatOracleGlobalPPS(
            address(admin),
            123,
            address(maatAddressProvider)
        );
        vm.expectRevert("MaatAddressProviderV1: Oracle is not set");
        address prevOracle = maatAddressProvider.oracle();

        vm.startPrank(admin);
        maatAddressProvider.changeOracle(address(oracle));
        address _oracle = maatAddressProvider.oracle();
        assertEq(_oracle, address(oracle));
    }

    function test_ChangeOracle_RevertIf_InterfaceIsNotSupported() public {
        vm.startPrank(admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                MaatAddressProviderV1.AddressIsNotOracle.selector,
                address(maatAddressProvider)
            )
        );
        maatAddressProvider.changeOracle(address(maatAddressProvider));
    }

    function test_ChangeIncentiveController() public {
        vm.expectRevert(
            "MaatAddressProviderV1: IncentiveController is not set"
        );
        maatAddressProvider.incentiveController();

        vm.startPrank(admin);
        address prevIncentiveController = address(0x12796754456798987654);
        maatAddressProvider.changeIncentiveController(prevIncentiveController);

        address incentiveController = address(0x123);
        prevIncentiveController = maatAddressProvider.incentiveController();

        maatAddressProvider.changeIncentiveController(incentiveController);
        address _incentiveController = maatAddressProvider
            .incentiveController();
        assertEq(_incentiveController, incentiveController);
    }

    function test_ChangeAdmin() public {
        address newAdmin = address(0x123);
        address prevAdmin = maatAddressProvider.admin();
        assertEq(prevAdmin, admin);

        vm.startPrank(admin);
        maatAddressProvider.changeAdmin(newAdmin);
        address _admin = maatAddressProvider.admin();
        assertEq(_admin, newAdmin);
    }
}
