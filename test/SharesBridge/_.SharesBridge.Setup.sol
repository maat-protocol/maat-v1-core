// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MaatSharesBridge} from "../../src/periphery/MaatSharesBridge.sol";

import {LayerZeroHelper, TestHelperOz5} from "./_.LayerZeroEndpoint.Setup.sol";

import {ERC20Mock} from "../mock/ERC20Mock.sol";

// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import "../../src/interfaces/IExecutor.sol";

// import {IStrategy as IStrategyFromStrategies} from "maat-strategies/contracts/interfaces/IStrategy.sol";
// import "../../src/core/MaatVaultV1.sol";

// import {MaatOracleGlobalPPS} from "../../src/periphery/MaatOracleGlobalPPS.sol";
// import "../../src/interfaces/IMaatVaultV1.sol";
// import {YearnV3Strategy, Strategy} from "maat-strategies/contracts/strategies/Yearn/YearnV3Strategy.sol";

import {MaatVaultV1} from "../../src/core/MaatVaultV1.sol";

import {MaatAddressProviderV1} from "../../src/periphery/MaatAddressProviderV1.sol";

contract SharesBridgeSetup is LayerZeroHelper {
    MaatAddressProviderV1 addressProviderA;
    MaatAddressProviderV1 addressProviderB;

    MaatSharesBridge bridgeA;
    MaatSharesBridge bridgeB;

    MaatVaultV1 vaultA;
    MaatVaultV1 vaultB;

    ERC20Mock usdcA;
    ERC20Mock usdcB;

    function setUp() public override {
        super.setUp();

        setUpEndpoints();

        usdcA = _deployERC20("USDC", "USDC");
        usdcB = _deployERC20("USDC", "USDC");

        addressProviderA = new MaatAddressProviderV1();
        addressProviderA.initialize(address(this));

        addressProviderB = new MaatAddressProviderV1();
        addressProviderB.initialize(address(this));

        vaultA = _deployVault(address(usdcA), eidA, addressProviderA);
        vaultB = _deployVault(address(usdcB), eidB, addressProviderB);

        addressProviderA.addVault(address(vaultA));
        addressProviderB.addVault(address(vaultB));

        bridgeA = new MaatSharesBridge(
            address(addressProviderA),
            address(endPointA),
            address(this)
        );

        bridgeB = new MaatSharesBridge(
            address(addressProviderB),
            address(endPointB),
            address(this)
        );

        addressProviderA.changeSharesBridge(address(bridgeA));
        addressProviderB.changeSharesBridge(address(bridgeB));

        address[] memory bridges = new address[](2);
        bridges[0] = address(bridgeA);
        bridges[1] = address(bridgeB);

        wireOApps(bridges);

        _addRelatedVaults(vaultA, eidB, address(vaultB));
        _addRelatedVaults(vaultB, eidA, address(vaultA));

        _mintVaultShares(vaultA, address(this), 1e20);
    }

    function _deployVault(
        address asset,
        uint32 chainEid,
        MaatAddressProviderV1 addressProvider
    ) internal returns (MaatVaultV1 vault) {
        vault = new MaatVaultV1(
            address(this),
            address(asset),
            1e18,
            address(addressProvider),
            address(0),
            address(0),
            chainEid
        );
    }

    function _deployERC20(
        string memory _name,
        string memory _symbol
    ) internal returns (ERC20Mock token) {
        token = new ERC20Mock(_name, _symbol);
    }

    function _mintVaultShares(
        MaatVaultV1 vault,
        address to,
        uint amount
    ) internal {
        vm.prank(address(bridgeA));
        vault.finishSharesBridge(to, amount);
    }

    function _addRelatedVaults(
        MaatVaultV1 vault,
        uint32 _dstEid,
        address _vault
    ) internal {
        uint32[] memory dstEids = new uint32[](1);
        address[] memory vaults = new address[](1);

        dstEids[0] = _dstEid;
        vaults[0] = _vault;

        vault.addRelatedVaults(dstEids, vaults);
    }
}
