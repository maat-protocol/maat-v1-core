// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {SharesBridgeSetup} from "./_.SharesBridge.Setup.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {IMaatSharesBridge} from "../../src/interfaces/IMaatSharesBridge.sol";
import {console2} from "forge-std/console2.sol";

contract SharesBridgeTest is SharesBridgeSetup {
    using OptionsBuilder for bytes;

    function test_bridgeShares() public {
        uint128 gas = 100000;
        uint256 amount = vaultA.balanceOf(address(this));

        assertEq(vaultA.totalSupply(), amount);
        assertEq(vaultB.totalSupply(), 0);

        assertEq(vaultA.balanceOf(address(this)), amount);
        assertEq(vaultB.balanceOf(address(this)), 0);

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(gas, 0);

        (uint256 nativeFee, ) = bridgeA.quote(
            eidB,
            IMaatSharesBridge.BridgeData(
                address(this),
                amount,
                address(vaultB)
            ),
            options,
            false
        );

        vaultA.bridgeShares{value: nativeFee}(eidB, amount, options);

        verifyPackets(uint32(eidB), addressToBytes32(address(bridgeB))); // finish bridge

        assertEq(vaultA.balanceOf(address(this)), 0);
        assertEq(vaultB.balanceOf(address(this)), amount);

        assertEq(vaultA.totalSupply(), 0);
        assertEq(vaultB.totalSupply(), amount);
    }
}
