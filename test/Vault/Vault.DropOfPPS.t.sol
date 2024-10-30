// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";
import {Strategy} from "maat-strategies/contracts/Strategy.sol";
import {console} from "forge-std/console.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract TestVaultWhenPPSDrops is MaatVaultTestSetup {
    uint256 internal _precisionMultiplier;
    uint112 internal _lowerPPS;

    function _afterSetUp() internal override {
        _precisionMultiplier = 10 ** oracle.decimals();
        _lowerPPS = 98e6;
    }

    function test_defaultOracleValue() public view {
        uint pps = oracle.getGlobalPPS(address(maatVault));
        assertEq(pps, 10 ** 8);
    }

    /// @dev PPS is 98% of initial value
    function test_deposit_afterPPSDrop() public {
        _changePPS(_lowerPPS);

        uint amount = 100e6;

        uint shares = maatVault.deposit(amount, address(this));

        // Old PPS = 1e8 must be used
        assertEq(shares, amount);
    }

    function test_mint_afterPPSDrop() public {
        _changePPS(_lowerPPS);

        uint assets = 100e6;
        uint shares = maatVault.convertToShares(assets);

        console.log("shares", shares);

        maatVault.mint(shares, address(this));

        // Old PPS = 1e8 must be used
        assertEq(shares, assets);
    }

    function test_withdraw_afterPPSDrop() public {
        _changePPS(_lowerPPS);

        uint amount = 100e6;

        uint shares = maatVault.deposit(amount, address(this));

        maatVault.approve(address(maatVault), type(uint).max);

        bytes memory err = abi.encodeWithSelector(
            IERC20Errors.ERC20InsufficientBalance.selector,
            address(this),
            amount,
            maatVault.convertToSharesByLowerPPS(amount)
        );

        vm.expectRevert(err);
        maatVault.withdraw(amount, address(this), address(this));

        uint assetsWithdrawable = maatVault.convertToAssetsByLowerPPS(shares);
        maatVault.withdraw(assetsWithdrawable, address(this), address(this));

        // Loss in withdrawableAmount is equal to percentage drop in PPS
        assertEq((amount * _lowerPPS) / 1e8, assetsWithdrawable);
    }

    function test_redeem_afterPPSDrop() public {
        _changePPS(_lowerPPS);

        uint amount = 100e6;

        uint shares = maatVault.deposit(amount, address(this));

        maatVault.approve(address(maatVault), type(uint).max);

        uint assets = maatVault.redeem(shares, address(this), address(this));

        // Loss in withdrawableAmount is equal to percentage drop in PPS
        assertEq((amount * _lowerPPS) / 1e8, assets);
    }

    function _changePPS(uint112 value) internal {
        vm.warp(block.timestamp + 1 days);

        uint112[] memory newPPS = new uint112[](1);
        newPPS[0] = value;

        address[] memory vaults = new address[](1);
        vaults[0] = address(maatVault);

        oracle.updateGlobalPPS(vaults, newPPS);
    }
}
