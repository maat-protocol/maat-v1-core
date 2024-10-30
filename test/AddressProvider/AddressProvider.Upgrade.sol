// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {MaatAddressProviderTestSetup, MaatAddressProviderV1} from "./_AddressProvider.Setup.sol";

contract AddressProviderSettersFuncTesting is MaatAddressProviderTestSetup {
    function test_Upgrade() public {
        MaatAddressProviderUpgrade newImplementation = new MaatAddressProviderUpgrade();

        vm.startPrank(admin);
        assertNotEq(address(maatAddressProvider.admin()), address(0x0));

        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(maatAddressProvider)),
            address(newImplementation),
            abi.encodeWithSignature("initialize()")
        );

        assertEq(address(maatAddressProvider.admin()), address(0x0));
        assertEq(
            MaatAddressProviderUpgrade(address(maatAddressProvider))
                .newVariable(),
            "new"
        );
        assertEq(
            maatAddressProvider.supportsInterface(
                bytes4(keccak256("MAAT.V2.AddressProvider"))
            ),
            true
        );
    }
}

contract MaatAddressProviderUpgrade is MaatAddressProviderV1 {
    string public newVariable;

    function initialize() public reinitializer(2) {
        admin = address(0x0);

        newVariable = "new";

        AddressProviderInterfaceId = bytes4(
            keccak256("MAAT.V2.AddressProvider")
        );

        _registerInterface(AddressProviderInterfaceId);
    }
}
