// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {TransparentUpgradeableProxy, ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "../../src/interfaces/IMaatVaultV1.sol";

import {TestUtils, Vm} from "../utils.sol";

import {MaatVaultV1} from "../../src/core/MaatVaultV1.sol";

import {YearnV3Strategy, Strategy} from "maat-strategies/contracts/strategies/Yearn/YearnV3Strategy.sol";
import {IStrategy as IStrategyFromStrategies} from "maat-strategies/contracts/interfaces/IStrategy.sol";

import {MaatOracleGlobalPPS} from "../../src/periphery/MaatOracleGlobalPPS.sol";
import {MaatAddressProviderV1} from "../../src/periphery/MaatAddressProviderV1.sol";

contract MaatAddressProviderTestSetup is TestUtils {
    // Arbitrum
    uint32 public chainId = 42161;
    uint public forkBlockNumber = 222806410;

    MaatOracleGlobalPPS oracle;
    MaatVaultV1 MaatVaultUSDT;
    MaatVaultV1 MaatVaultUSDC;
    Strategy strategyUSDT;
    Strategy strategyUSDC;

    address commander = address(0xad);
    address watcher = address(0xdae);

    // USDT Arb
    ERC20 public USDT = ERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    ERC20 public USDC = ERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    address yearnUSDTVault = 0xc0ba9bfED28aB46Da48d2B69316A3838698EF3f5;
    address yearnUSDCVault = 0x6FAF8b7fFeE3306EfcFc2BA9Fec912b4d49834C1;

    address admin = address(uint160(uint256(keccak256("admin"))));

    address stargateAdapter =
        address(uint160(uint256(keccak256("stargateAdapter"))));

    bytes32 strategyId;
    uint amountMin = 100;

    ProxyAdmin proxyAdmin;

    address feeToPerformance = address(0xdeadbeef);
    uint performanceFee = 2 * 10 ** 7;

    MaatAddressProviderV1 maatAddressProvider;

    function setUp() public virtual {
        fork(chainId, forkBlockNumber);

        strategyUSDT = _setUpYearnV3Strategy(USDT);
        strategyUSDC = _setUpYearnV3Strategy(USDC);

        MaatAddressProviderV1 _implementation = new MaatAddressProviderV1();

        vm.recordLogs();

        TransparentUpgradeableProxy maatAddressProviderProxy = new TransparentUpgradeableProxy(
                address(_implementation),
                admin,
                ""
            );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        address _proxyAdmin;

        (, _proxyAdmin) = abi.decode(entries[2].data, (address, address));

        proxyAdmin = ProxyAdmin(_proxyAdmin);

        maatAddressProvider = MaatAddressProviderV1(
            address(maatAddressProviderProxy)
        );
        maatAddressProvider.initialize(admin);

        oracle = new MaatOracleGlobalPPS(
            admin,
            10 ** 20,
            address(maatAddressProvider)
        );

        bytes4 interfaceId = bytes4(keccak256("MAAT.V1.AddressProvider"));

        require(
            maatAddressProvider.supportsInterface(interfaceId),
            "AddressProvider: something went wrong"
        );

        MaatVaultUSDT = _setUpVault(USDT, address(maatAddressProvider));
        MaatVaultUSDC = _setUpVault(USDC, address(maatAddressProvider));
        _afterSetUp();
    }

    function _setUpVault(
        ERC20 token,
        address _addressProvider
    ) internal returns (MaatVaultV1) {
        return
            new MaatVaultV1(
                address(this),
                address(token),
                0,
                _addressProvider,
                commander,
                watcher,
                1
            );
    }

    function _setUpYearnV3Strategy(
        ERC20 token
    ) internal returns (YearnV3Strategy) {
        IStrategyFromStrategies.StrategyParams
            memory strategyParams = IStrategyFromStrategies.StrategyParams(
                42161,
                "Yearn",
                3,
                address(token),
                address(0)
            );

        return
            new YearnV3Strategy(
                strategyParams,
                address(0),
                feeToPerformance,
                performanceFee
            );
    }

    function _afterSetUp() internal virtual {}

    function _labelContracts() internal {
        vm.label(address(USDT), "USDT Proxy");
        vm.label(address(MaatVaultUSDT), "MaatVaultV1 USDT");
        vm.label(address(MaatVaultUSDC), "MaatVaultV1 USDC");
        vm.label(address(oracle), "Oracle");
        vm.label(address(strategyUSDT), "Strategy USDT");
        vm.label(address(strategyUSDC), "Strategy USDC");
        vm.label(address(maatAddressProvider), "MaatAddressProvider");
        vm.label(address(admin), "admin");
        // vm.label(USDT, "USDT Proxy");
        // // vm.label(address(token), "USDT");
        // vm.label(address(MaatVaultV1), "MaatVaultV1");
        // vm.label(address(oracle), "Oracle");
        // vm.label(address(strategy), "Strategy");
    }
}
