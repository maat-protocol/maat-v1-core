// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IMaatOracleGlobalPPS} from "../interfaces/IMaatOracleGlobalPPS.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC165Registry} from "../lib/ERC165Registry.sol";
import {AddressProviderKeeper} from "../core/base/AddressProviderKeeper.sol";

/// @title MaatOracleGlobalPPS
/// @notice Oracle for global price per share of MaatVaults
/// @dev price per share is calculated off chain and submitted to the contract
/// @dev This contract is a temporary solution that is dependent on team supported keepers
/// @dev and oracle assumes that keepers submits correct values
/// @dev In future it will be replaced with more safe and decentralized oracle
/// @dev utilizing fully on-chain calculation through omnichain data passing
contract MaatOracleGlobalPPS is
    IMaatOracleGlobalPPS,
    Ownable,
    ERC165Registry,
    AddressProviderKeeper
{
    bytes4 constant MaatOracleGlobalPPSInterfaceId =
        bytes4(keccak256("MAAT.V1.Oracle"));

    ///@dev DELTA_PPS_PER_SECOND determines how much the PPS can change over time
    uint public immutable DELTA_PPS_PER_SECOND; //RECOMMENDED VALUE: 3 (3 -> 0.25% Per Day -> 94% APR)

    uint private constant _decimals = 8;

    mapping(address vault => bool) public isInitialized;

    mapping(address => PricePerShare) public globalPricePerShare;

    /* ========== ERRORS ========== */
    error VaultIsNotInitialized(address vault);

    /* ========== CONSTRUCTOR ========== */
    constructor(
        address admin,
        uint delta,
        address addressProvider
    ) Ownable(admin) AddressProviderKeeper(addressProvider) {
        DELTA_PPS_PER_SECOND = delta;
        _registerInterface(MaatOracleGlobalPPSInterfaceId);
    }

    /* ========== INIT ========== */

    /// @dev Initialize accepts arbitrary prevPPS and pricePerShare values
    /// @dev to add new chains after some lifetime of Vault
    function initPPS(
        address vault,
        uint112 prevPricePerShare,
        uint112 pricePerShare
    ) external {
        require(
            addressProvider().isVault(vault),
            "MaatOracleGlobalPPS: Invalid vault address"
        );
        require(
            !isInitialized[vault],
            "MaatOracleGlobalPPS: PricePerShare for this vault already initialized"
        );

        _updatePPS(prevPricePerShare, vault);
        _updatePPS(pricePerShare, vault);

        isInitialized[vault] = true;

        uint32 _lastUpdateTime = globalPricePerShare[vault].lastUpdateTime;

        emit UpdatePPS(
            vault,
            globalPricePerShare[vault].pricePerShare,
            globalPricePerShare[vault].prevPricePerShare,
            _lastUpdateTime
        );
    }

    /* ========== UPDATE PPS FUNCTION ========== */

    function updateGlobalPPS(
        address[] calldata vaults,
        uint112[] calldata newPricePerShare
    ) external onlyOwner {
        require(
            vaults.length == newPricePerShare.length,
            "MaatOracleGlobalPPS: Array length mismatch"
        );

        for (uint i = 0; i < vaults.length; i++) {
            uint112 pricePerShare = globalPricePerShare[vaults[i]]
                .pricePerShare;
            uint32 _lastUpdateTime = globalPricePerShare[vaults[i]]
                .lastUpdateTime;

            require(
                _checkDeltaPPS(
                    newPricePerShare[i],
                    pricePerShare,
                    _lastUpdateTime
                ),
                "MaatOracleGlobalPPS: Insufficient value of price per share"
            );

            _updatePPS(newPricePerShare[i], vaults[i]);

            emit UpdatePPS(
                vaults[i],
                globalPricePerShare[vaults[i]].pricePerShare,
                globalPricePerShare[vaults[i]].prevPricePerShare,
                _lastUpdateTime
            );
        }
    }

    /* ========== EXTERNAL ========== */
    function getPrevGlobalPPS(
        address vault
    ) external view returns (uint prevPricePerShare, uint32 prevUpdateTime) {
        prevPricePerShare = globalPricePerShare[vault].prevPricePerShare;
        if (prevPricePerShare == 0) revert VaultIsNotInitialized(vault);
        
        prevUpdateTime = globalPricePerShare[vault].prevUpdateTime;
    }

    function getGlobalPPS(
        address vault
    ) external view returns (uint pricePerShare, uint32 lastUpdateTime) {
        pricePerShare = globalPricePerShare[vault].pricePerShare;
        if (pricePerShare == 0) revert VaultIsNotInitialized(vault);

        lastUpdateTime = globalPricePerShare[vault].lastUpdateTime;
    }

    function decimals() external pure returns (uint) {
        return _decimals;
    }

    /* ========== INTERNAL ========== */
    function _checkDeltaPPS(
        uint112 newPPS,
        uint112 prevPPS,
        uint32 _lastUpdateTime
    ) internal view returns (bool) {
        uint deltaTime = block.timestamp - _lastUpdateTime;

        if (_subAbs(newPPS, prevPPS) < deltaTime * DELTA_PPS_PER_SECOND)
            return true;
        else return false;
    }

    function _updatePPS(uint112 newPricePerShare, address vault) internal {
        PricePerShare storage pps = globalPricePerShare[vault];

        pps.prevPricePerShare = pps.pricePerShare;

        pps.pricePerShare = newPricePerShare;

        pps.prevUpdateTime = pps.lastUpdateTime;

        pps.lastUpdateTime = uint32(block.timestamp);
    }

    function _subAbs(uint x, uint y) private pure returns (uint) {
        if (x > y) return x - y;
        else return y - x;
    }
}
