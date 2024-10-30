// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IMaatAddressProvider {
    /**
     * @notice Add a strategy to a vault
     * @param strategy The address of the strategy to add
     * @dev This function can only be called by a vault
     */

    function addStrategy(address strategy) external;

    /**
     * @notice Remove a strategy from a vault
     * @param strategy The address of the strategy to remove
     * @dev This function can only be called by a vault
     */

    function removeStrategy(address strategy) external;

    /**
     * @notice Add a vault
     * @param vault The address of the vault to add
     * @dev This function can only be called by the admin
     */

    function addVault(address vault) external;

    /**
     * @notice Remove a vault
     * @param vault The address of the vault to remove
     * @dev This function can only be called by the admin
     */

    function removeVault(address vault) external;

    function changeOracle(address newOracle) external;

    function changeIncentiveController(address newIncentiveController) external;

    function changeStargateAdapter(address newStargateAdapter) external;

    function changeAdmin(address newAdmin) external;

    function changeSharesBridge(address newSharesBridge) external;

    function isVault(address vault) external view returns (bool isVault);

    function isStrategy(
        address strategy
    ) external view returns (bool isStrategy);

    function getVaults() external view returns (address[] memory vaults);

    function getStrategies()
        external
        view
        returns (address[] memory strategies);

    function oracle() external view returns (address oracle);

    function stargateAdapter() external view returns (address stargateAdapter);

    function incentiveController()
        external
        view
        returns (address incentiveController);

    function admin() external view returns (address admin);

    function sharesBridge() external view returns (address sharesBridge);
}
