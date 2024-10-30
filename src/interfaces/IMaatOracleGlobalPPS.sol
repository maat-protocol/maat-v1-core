// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IMaatOracleGlobalPPS {
    struct PricePerShare {
        uint112 pricePerShare;
        uint112 prevPricePerShare;
        uint32 lastUpdateTime;
        uint32 prevUpdateTime;
    }

    event UpdatePPS(
        address vault,
        uint256 pricePerShare,
        uint256 prevPricePerShare,
        uint32 prevUpdateTime
    );

    ///@notice This function returns the global PricePerShare value.
    function getGlobalPPS(address vault) external view returns (uint256);

    function getPrevGlobalPPS(address vault) external view returns (uint);

    ///@notice This function updates the global PricePerShare value.
    ///@dev This function requires that the caller is an administrator or has appropriate access rights.
    function updateGlobalPPS(
        address[] calldata vault,
        uint112[] calldata _pricePerShare
    ) external;

    function decimals() external view returns (uint);
}
