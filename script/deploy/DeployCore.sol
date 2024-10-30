// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {MaatVaultV1} from "../../src/core/MaatVaultV1.sol";
import {MaatAddressProviderV1} from "../../src/periphery/MaatAddressProviderV1.sol";
import {MaatOracleGlobalPPS} from "../../src/periphery/MaatOracleGlobalPPS.sol";

import {CREATE3Factory} from "@layerzerolabs/create3-factory/contracts/CREATE3Factory.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract DeployCore {
    function _deploy_MaatVault(
        address _create3Factory,
        address _owner,
        address _assetAddress,
        uint256 _minAmount,
        address _addressProvider,
        address _commander,
        address _watcher,
        uint32 _chainEid,
        string memory _forSalt
    ) internal returns (MaatVaultV1 maatVault) {
        CREATE3Factory factory = CREATE3Factory(_create3Factory);

        bytes32 salt = keccak256(abi.encodePacked(_forSalt));
        bytes memory _deployedCode = type(MaatVaultV1).creationCode;
        bytes memory params = abi.encode(
            _owner,
            _assetAddress,
            _minAmount,
            _addressProvider,
            _commander,
            _watcher,
            _chainEid
        );
        bytes memory creationCode = abi.encodePacked(_deployedCode, params);

        address MaatVaultAddress = factory.deploy(salt, creationCode);

        maatVault = MaatVaultV1(payable(MaatVaultAddress));
    }

    function _deploy_MaatAddressProviderV1(
        address _create3Factory,
        address _proxyAdmin,
        address _providerAdmin,
        string memory _forSalt
    ) internal returns (MaatAddressProviderV1 addressProvider) {
        CREATE3Factory factory = CREATE3Factory(_create3Factory);

        MaatAddressProviderV1 implementation = new MaatAddressProviderV1();

        bytes32 salt = keccak256(abi.encodePacked(_forSalt));
        bytes memory _deployedCode = type(TransparentUpgradeableProxy)
            .creationCode;

        bytes memory params = abi.encode(
            implementation,
            _proxyAdmin,
            abi.encodeWithSignature("initialize(address)", _providerAdmin)
        );

        bytes memory creationCode = abi.encodePacked(_deployedCode, params);

        address addr = factory.deploy(salt, creationCode);

        addressProvider = MaatAddressProviderV1(addr);
    }

    function _deploy_MaatOracleGlobalPPS(
        address _create3Factory,
        address _admin,
        uint256 _delta,
        address _addressProvider,
        string memory _forSalt
    ) internal returns (MaatOracleGlobalPPS oracle) {
        CREATE3Factory factory = CREATE3Factory(_create3Factory);

        bytes32 salt = keccak256(abi.encodePacked(_forSalt));
        bytes memory _deployedCode = type(MaatOracleGlobalPPS).creationCode;

        bytes memory params = abi.encode(_admin, _delta, _addressProvider);

        bytes memory creationCode = abi.encodePacked(_deployedCode, params);

        address addr = factory.deploy(salt, creationCode);

        oracle = MaatOracleGlobalPPS(addr);
    }
}
