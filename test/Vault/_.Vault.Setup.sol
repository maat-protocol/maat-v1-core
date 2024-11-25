// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "../../src/interfaces/IExecutor.sol";

import {IStrategy as IStrategyFromStrategies} from "maat-strategies/contracts/interfaces/IStrategy.sol";
import "../../src/core/MaatVaultV1.sol";

import {MaatOracleGlobalPPS} from "../../src/periphery/MaatOracleGlobalPPS.sol";
import "../../src/interfaces/IMaatVaultV1.sol";
import {YearnV3Strategy, Strategy} from "maat-strategies/contracts/strategies/Yearn/YearnV3Strategy.sol";
import {MaatAddressProviderV1} from "src/periphery/MaatAddressProviderV1.sol";
import "../../src/core/vault/Vault.sol";

contract MaatVaultHarness is MaatVaultV1 {
    constructor(
        address _owner,
        address _token,
        uint _minAmount,
        address _oracle,
        address commander,
        address watcher,
        uint32 chainEid
    )
        MaatVaultV1(
            _owner,
            _token,
            _minAmount,
            _oracle,
            commander,
            watcher,
            chainEid
        )
    {}

    function depositInStrategy(
        bytes32 _strategyId,
        uint256 _amount,
        bytes32 _intentionId
    ) public {
        super._depositInStrategy(_strategyId, _amount, _intentionId);
    }

    function withdrawFromStrategy(
        bytes32 _strategyId,
        uint256 _amount,
        bytes32 _intentionId
    ) public {
        super._withdrawFromStrategy(_strategyId, _amount, _intentionId);
    }

    function bridge(uint _amount, uint _chainId, bytes32 intentionId) public {
        super._bridge(_amount, uint32(_chainId), intentionId);
    }

    function bridgeToUser(
        uint amount,
        address _receiver,
        uint32 dstEid
    ) external {
        super._bridgeToUser(amount, _receiver, dstEid);
    }

    function convertToAssetsByLowerPPS(uint shares) public view returns (uint) {
        return super._convertToAssetsByLowerPPS(shares);
    }

    function convertToSharesByLowerPPS(uint assets) public view returns (uint) {
        return super._convertToSharesByLowerPPS(assets);
    }

    function calculateFee(uint amount, uint112 fee) public view returns (uint) {
        return super._calculateFee(amount, fee);
    }

    function setNonce(uint _nonce) public {
        _nonces[tx.origin] = _nonce;
    }

    function getIntentionId(uint _nonce) public view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        return
            keccak256(
                abi.encodePacked(
                    address(this),
                    tx.origin,
                    _nonces[tx.origin],
                    chainId
                )
            );
    }

    // Overridden Idle calculations for tests

    uint internal idle_;

    function idle() public view override returns (uint) {
        return idle_;
    }

    function _increaseIdle(uint value) internal virtual override {
        idle_ += value;
    }

    function _decreaseIdle(uint value) internal virtual override {
        require(
            value <= idle_,
            "MaatVaultV1: Arithmetic error during idle calculations"
        );
        idle_ -= value;
    }

    function setIdle(uint amount) public {
        idle_ = amount;
    }
}

contract MaatVaultTestSetup is TestUtils {
    // Arbitrum
    uint32 public chainId = 42161;
    uint public forkBlockNumber = 222806410;

    MaatVaultHarness maatVault;
    MaatOracleGlobalPPS oracle;
    Strategy strategy;

    address commander = address(0xad);
    address watcher = address(0xdae);

    MaatAddressProviderV1 addressProvider;

    // USDT Arb
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    ERC20 public token = ERC20(USDT);

    address yearnUSDTVault = 0xc0ba9bfED28aB46Da48d2B69316A3838698EF3f5;

    address admin = address(this);

    bytes32 strategyId;
    uint amountMin = 100;

    address feeToPerformance = address(0xdeadbeef);
    uint performanceFee = 2 * 10 ** 7;

    uint112 initialPPS = 10 ** 8;

    function setUp() public virtual {
        fork(chainId, forkBlockNumber);

        /* ======== ADDRESS PROVIDER SETUP ======== */

        addressProvider = new MaatAddressProviderV1();
        addressProvider.initialize(admin);

        /* ======== VAULT SETUP ======== */

        maatVault = new MaatVaultHarness(
            address(this),
            address(token),
            amountMin,
            address(addressProvider),
            commander,
            watcher,
            1
        );

        addressProvider.addVault(address(maatVault));

        /* ======== HANDLE TOKENS ======== */

        deal(address(token), address(this), 1_000_000e6);

        token.approve(address(maatVault), 1_000_000e6);

        /* ======== STRATEGY SETUP ======== */

        YearnV3Strategy yearnV3Strategy = _setUpYearnV3Strategy(
            "YEARN FINANCE"
        );

        strategy = Strategy(yearnV3Strategy);

        strategyId = strategy.getStrategyId();

        addressProvider.addStrategy(address(strategy));

        maatVault.addStrategy(address(strategy));

        /* ======== ORACLE SETUP ======== */

        oracle = new MaatOracleGlobalPPS(
            admin,
            10 ** 20, // Recommended value = 116 and it equals to 10% change per day
            address(addressProvider)
        );

        addressProvider.changeOracle(address(oracle));

        oracle.initPPS(address(maatVault), initialPPS, initialPPS);

        /* ======== MISC SETUP ======== */

        maatVault.setFees(0, 0);
        maatVault.setIdle(10 ** 70);

        /* ======== LABELS ======== */

        vm.label(USDT, "USDT Proxy");
        vm.label(0xf31e1AE27e7cd057C1D6795a5a083E0453D39B50, "USDT");
        vm.label(yearnUSDTVault, "Yearn USDT Vault");

        _afterSetUp();
    }

    function _setUpYearnV3Strategy(
        string memory _protocolName
    ) internal returns (YearnV3Strategy) {
        IStrategyFromStrategies.StrategyParams
            memory strategyParams = IStrategyFromStrategies.StrategyParams(
                42161,
                _protocolName,
                3,
                address(token),
                yearnUSDTVault
            );

        return
            new YearnV3Strategy(
                strategyParams,
                address(addressProvider),
                feeToPerformance,
                performanceFee
            );
    }

    function _afterSetUp() internal virtual {}

    function _labelContracts() internal {
        vm.label(USDT, "USDT Proxy");
        // vm.label(address(token), "USDT");
        vm.label(address(maatVault), "MaatVaultV1");
        vm.label(address(oracle), "Oracle");
        vm.label(address(strategy), "Strategy");
    }
}
