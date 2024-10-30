// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC165Checker, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {IMaatVaultV1} from "../interfaces/IMaatVaultV1.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {IMaatAddressProvider} from "../interfaces/IMaatAddressProvider.sol";
import {ERC165Registry} from "../lib/ERC165Registry.sol";

contract MaatAddressProviderV1 is
    IMaatAddressProvider,
    Initializable,
    ERC165Registry
{
    bytes4 AddressProviderInterfaceId;
    bytes4 MaatVaultInterfaceId;
    bytes4 StrategyInterfaceId;
    bytes4 MaatOracleGlobalPPSInterfaceId;

    address[] _vaults;
    address[] _strategies;

    address private _oracle;
    address private _stargateAdapter;
    address private _incentiveController;
    address private _sharesBridge;

    address public override admin;

    mapping(address vault => bool isVault) public override isVault;
    mapping(address strategy => bool isStrategy) public override isStrategy;

    function initialize(address _admin) public initializer {
        admin = _admin;

        MaatVaultInterfaceId = bytes4(keccak256("MAAT.V1.Vault"));
        StrategyInterfaceId = bytes4(keccak256("MAAT.V1.Strategy"));
        AddressProviderInterfaceId = bytes4(
            keccak256("MAAT.V1.AddressProvider")
        );
        MaatOracleGlobalPPSInterfaceId = bytes4(keccak256("MAAT.V1.Oracle"));

        _registerInterface(AddressProviderInterfaceId);
        _registerInterface(type(IERC165).interfaceId);
    }

    function oracle() external view override returns (address) {
        require(
            _oracle != address(0),
            "MaatAddressProviderV1: Oracle is not set"
        );
        return _oracle;
    }

    function stargateAdapter() external view override returns (address) {
        require(
            _stargateAdapter != address(0),
            "MaatAddressProviderV1: StargateAdapter is not set"
        );
        return _stargateAdapter;
    }

    function incentiveController() external view override returns (address) {
        require(
            _incentiveController != address(0),
            "MaatAddressProviderV1: IncentiveController is not set"
        );
        return _incentiveController;
    }

    function sharesBridge() external view override returns (address) {
        require(
            _sharesBridge != address(0),
            "MaatAddressProviderV1: SharesBridge is not set"
        );
        return _sharesBridge;
    }

    /* ======== EXTERNAL ======== */

    function addStrategy(address strategy) external override onlyAdmin {
        if (isStrategy[strategy]) revert AlreadyAdded();
        _validateStrategyInterface(strategy);

        isStrategy[strategy] = true;
        _strategies.push(strategy);

        emit StrategyRegistered(
            strategy,
            IStrategy(strategy).getStrategyId(),
            (IStrategy(strategy)).getStrategyParams()
        );
    }

    function removeStrategy(address strategy) external override onlyAdmin {
        if (!isStrategy[strategy]) revert NotAdded();

        isStrategy[strategy] = false;
        _removeAddress(_strategies, strategy);

        emit StrategyDeprecated(strategy);
    }

    function addVault(address vault) external override onlyAdmin {
        if (isVault[vault]) revert AlreadyAdded();
        _validateVaultInterface(vault);

        isVault[vault] = true;
        _vaults.push(vault);

        address asset = IMaatVaultV1(vault).asset();
        uint8 decimals = IMaatVaultV1(asset).decimals();
        string memory name = IMaatVaultV1(asset).name();
        string memory symbol = IMaatVaultV1(asset).symbol();

        emit VaultRegistered(vault, asset, name, symbol, decimals);
    }

    function removeVault(address vault) external override onlyAdmin {
        if (!isVault[vault]) revert NotAdded();

        isVault[vault] = false;
        _removeAddress(_vaults, vault);

        emit VaultDeprecated(vault);
    }

    function changeOracle(address newOracle) external override onlyAdmin {
        _validateOracleInterface(newOracle);
        emit OracleChanged(_oracle, newOracle);

        _oracle = newOracle;
    }

    function changeIncentiveController(
        address newIncentiveController
    ) external override onlyAdmin {
        emit IncentiveControllerChanged(
            _incentiveController,
            newIncentiveController
        );

        _incentiveController = newIncentiveController;
    }

    function changeStargateAdapter(
        address newStargateAdapter
    ) external override onlyAdmin {
        emit StargateAdapterChanged(_stargateAdapter, newStargateAdapter);

        _stargateAdapter = newStargateAdapter;
    }

    function changeAdmin(address newAdmin) external override onlyAdmin {
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function changeSharesBridge(
        address newSharesBridge
    ) external override onlyAdmin {
        emit SharesBridgeChanged(_sharesBridge, newSharesBridge);
        _sharesBridge = newSharesBridge;
    }

    /* ======== VIEW ======== */

    function getVaults()
        external
        view
        override
        returns (address[] memory vaults)
    {
        return _vaults;
    }

    function getStrategies()
        external
        view
        override
        returns (address[] memory strategies)
    {
        return _strategies;
    }

    /* ======== INTERNAL ======== */

    function _removeAddress(
        address[] storage array,
        address addressToRemove
    ) internal {
        uint256 arrayLength = array.length;
        address[] memory _array = array;
        if (arrayLength == 1) {
            array.pop();
            return;
        }
        for (uint i = 0; i < arrayLength; i++) {
            if (_array[i] == addressToRemove) {
                array[i] = _array[arrayLength - 1];
                array.pop();
                break;
            }
        }
    }

    function _validateVaultInterface(address _vault) internal view {
        if (!ERC165Registry(_vault).supportsInterface(MaatVaultInterfaceId))
            revert AddressIsNotMaatVault(_vault);
    }

    function _validateStrategyInterface(address strategy) internal view {
        if (!ERC165Registry(strategy).supportsInterface(StrategyInterfaceId))
            revert AddressIsNotStrategy(strategy);
    }

    function _validateOracleInterface(address oracle_) internal view {
        if (
            !ERC165Registry(oracle_).supportsInterface(
                MaatOracleGlobalPPSInterfaceId
            )
        ) revert AddressIsNotOracle(oracle_);
    }

    /* ======== EVENTS ======== */

    event StrategyDeprecated(address strategy);
    event StrategyRegistered(
        address strategy,
        bytes32 strategyId,
        IStrategy.StrategyParams params
    );

    event VaultDeprecated(address vault);
    event VaultRegistered(
        address vault,
        address asset,
        string assetName,
        string assetSymbol,
        uint8 decimals
    );

    event AdminChanged(address prevAdmin, address newAdmin);
    event OracleChanged(address prevOracle, address newOracle);
    event IncentiveControllerChanged(
        address prevIncentiveController,
        address newIncentiveController
    );
    event StargateAdapterChanged(
        address prevStargateAdapter,
        address newStargateAdapter
    );
    event SharesBridgeChanged(
        address prevSharesBridge,
        address newSharesBridge
    );

    /* ======== ERRORS ======== */

    error NotAdmin();
    error AlreadyAdded();
    error NotAdded();
    error AddressIsNotMaatVault(address addr);
    error AddressIsNotStrategy(address addr);
    error AddressIsNotOracle(address addr);

    /* ======== MODIFIERS ======== */

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }
}
