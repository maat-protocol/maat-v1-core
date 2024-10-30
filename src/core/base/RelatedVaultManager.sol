// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Roles} from "../execute/Roles.sol";

abstract contract RelatedVaultManager is Ownable {
    mapping(uint32 dstEid => address vault) private _relatedVaults;

    function addRelatedVaults(
        uint32[] calldata _dstEid,
        address[] calldata _vault
    ) public onlyOwner {
        require(
            _dstEid.length == _vault.length,
            "MaatVaultV1: Invalid input length"
        );

        for (uint i = 0; i < _dstEid.length; i++) {
            require(
                _relatedVaults[_dstEid[i]] == address(0),
                "MaatVaultV1: Vault already exists"
            );
            _relatedVaults[_dstEid[i]] = _vault[i];
        }
    }

    function removeRelatedVault(uint32 _dstEid) external onlyOwner {
        _relatedVaults[_dstEid] = address(0);
    }

    function getRelatedVault(
        uint32 _dstEid
    ) public view returns (address _vault) {
        _vault = _relatedVaults[_dstEid];
        require(_vault != address(0), "MaatVaultV1: Vault not found");
    }
}
