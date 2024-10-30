// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

import "../utils.sol";

import {DeployCore} from "../../script/deploy/DeployCore.sol";

import {MaatVaultV1} from "../../src/core/MaatVaultV1.sol";
import {MaatAddressProviderV1} from "../../src/periphery/MaatAddressProviderV1.sol";
import {MaatOracleGlobalPPS} from "../../src/periphery/MaatOracleGlobalPPS.sol";

contract DeployCoreTests is TestUtils, DeployCore {
    address create3Factory = 0x9fBB3DF7C40Da2e5A0dE984fFE2CCB7C47cd0ABf;

    address admin = address(0x7772281337425269);

    function setUp() public {}

    function test_deployVault() public {
        fork(1, 20461462);

        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // ethereum usdc

        MaatVaultV1 vault = _deployVault(usdc);

        assertEq(vault.asset(), usdc);
    }

    function _deployVault(address asset) private returns (MaatVaultV1 vault) {
        string memory forSalt = "MAAT.V1.0.Vault";

        address maatProvider = address(_deployProvider());

        vault = _deploy_MaatVault(
            create3Factory,
            admin,
            asset,
            1,
            maatProvider,
            admin,
            admin,
            30101, // ethereum eid
            forSalt
        );
    }

    function test_deployProviderOnDifferentChain() public {
        fork(42161, 239650040);
        address providerARB = address(_deployProvider());

        fork(1, 20461462);
        address providerETH = address(_deployProvider());

        assertEq(providerARB, providerETH);
    }

    function _deployProvider()
        private
        returns (MaatAddressProviderV1 provider)
    {
        string memory forSalt = "MAAT.V1.0.AddressProvider";

        provider = _deploy_MaatAddressProviderV1(
            create3Factory,
            admin,
            admin,
            forSalt
        );

        assertEq(provider.admin(), admin);
    }

    function test_deployOracleOnDifferentChain() public {
        fork(1, 20461462);
        address providerETH = address(_deployProvider());
        address oracleETH = address(_deployOracle(providerETH));

        fork(42161, 239650040);
        address providerARB = address(_deployProvider());
        address oracleARB = address(_deployOracle(providerARB));

        assertEq(oracleARB, oracleETH);
    }

    function _deployOracle(
        address addressProvider
    ) public returns (MaatOracleGlobalPPS oracle) {
        string memory forSalt = "MAAT.1.MaatOracleGlobalPPS";

        oracle = _deploy_MaatOracleGlobalPPS(
            create3Factory,
            admin,
            116,
            addressProvider,
            forSalt
        );
    }
}
