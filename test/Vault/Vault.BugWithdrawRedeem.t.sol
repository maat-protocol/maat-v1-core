// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./_.Vault.Setup.sol";

contract MaatVaultPreviewTesting is MaatVaultTestSetup {
    uint64 feeIn = 0;
    uint64 feeOut = 1e6;
    address _nonowner = address(0x00000001);

    function test_PreviewWithdraw() public {
        maatVault.setFees(feeIn, feeOut);

        vm.startPrank(_nonowner);

        uint depositAmount = 100e6;

        deal(USDT, _nonowner, depositAmount);

        IERC20(USDT).approve(address(maatVault), depositAmount);
        maatVault.deposit(depositAmount, _nonowner);

        // you have 100 shares
        // pps = 1
        // fee = 1%, so you can withdraw 99 usdt

        uint burnedShares = maatVault.previewWithdraw(99e6);

        // must be 100, but it's 99.99
        console.log("burnedShares", burnedShares);

        uint receivedAssets = maatVault.previewRedeem(100e6);

        // must be 99 and it's 99
        console.log("receivedAssets", receivedAssets);
    }
}
