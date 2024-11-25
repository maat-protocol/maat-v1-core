// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/periphery/MaatOracleGlobalPPS.sol";
import "test/Vault/_.Vault.Setup.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("USD Token", "USDT") {
        _mint(msg.sender, 10000000 * 10 ** 18);
    }
}

contract OracleTest is MaatVaultTestSetup {
    MockERC20 usdt;

    address nonAdmin = address(0x1);

    MaatVaultHarness secondMaatVault;

    function _afterSetUp() internal override {
        secondMaatVault = new MaatVaultHarness(
            address(this),
            address(token),
            amountMin,
            address(addressProvider),
            commander,
            watcher,
            1
        );

        addressProvider.addVault(address(secondMaatVault));
    }

    function test_UpdateGlobalPPS() public {
        skip(1000);
        uint112 newPPS = 100000010;
        uint skipInterval = 100;

        address[] memory vaults = new address[](1);
        uint112[] memory ppsArray = new uint112[](1);

        vaults[0] = address(maatVault);
        ppsArray[0] = newPPS;

        oracle.updateGlobalPPS(vaults, ppsArray);

        (uint prevPPS, ) = oracle.getPrevGlobalPPS(address(maatVault));
        assertEq(prevPPS, 10 ** 8);

        prevPPS = newPPS;
        newPPS = 100000100;

        ppsArray[0] = newPPS;

        skip(skipInterval);
        oracle.updateGlobalPPS(vaults, ppsArray);

        (uint currentPPSFromOracle, uint32 lastUpdateTime) = oracle
            .getGlobalPPS(address(maatVault));

        (uint prevPPSFromOracle, uint32 prevUpdateTime) = oracle
            .getPrevGlobalPPS(address(maatVault));

        // Assert Price Per Share

        assertEq(currentPPSFromOracle, newPPS);
        assertEq(prevPPSFromOracle, prevPPS);

        // Assert Update Time

        assertEq(lastUpdateTime, block.timestamp);
        assertEq(prevUpdateTime, block.timestamp - skipInterval);
    }

    function testAccessControl() public {
        uint112 newPPS = 300000000;

        address[] memory vaults = new address[](1);
        uint112[] memory ppsArray = new uint112[](1);

        vaults[0] = address(maatVault);
        ppsArray[0] = newPPS;

        vm.prank(nonAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                nonAdmin
            )
        );
        oracle.updateGlobalPPS(vaults, ppsArray);
    }

    function testDecimalsFunction() public view {
        assertEq(oracle.decimals(), 8);
    }

    function test_InitFunction_AlreadyInitialized() public {
        (uint currentPPS, ) = oracle.getGlobalPPS(address(maatVault));
        assertEq(currentPPS, 10 ** 8);

        vm.expectRevert(
            "MaatOracleGlobalPPS: PricePerShare for this vault already initialized"
        );
        oracle.initPPS(address(maatVault), initialPPS, initialPPS);
    }

    function test_InitFunction() public {
        uint112 prevPPS = 2e8;
        uint112 currentPPS = 3e8;

        oracle.initPPS(address(secondMaatVault), prevPPS, currentPPS);

        (uint currentPPSFromOracle, ) = oracle.getGlobalPPS(
            address(secondMaatVault)
        );
        assertEq(currentPPSFromOracle, currentPPS);

        (uint prevPPSFromOracle, ) = oracle.getPrevGlobalPPS(
            address(secondMaatVault)
        );
        assertEq(prevPPSFromOracle, prevPPS);
    }
}
