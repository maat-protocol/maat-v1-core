// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IMaatAddressProvider} from "../../interfaces/IMaatAddressProvider.sol";

contract AddressProviderKeeper {
    using ERC165Checker for address;

    IMaatAddressProvider private immutable _addressProvider;

    bytes4 public constant AddressProviderInterfaceId =
        bytes4(keccak256("MAAT.V1.AddressProvider"));

    error AddressIsNotAddressProvider(address addr);

    constructor(address addressProvider_) {
        _validateAddressProviderInterface(addressProvider_);

        _addressProvider = IMaatAddressProvider(addressProvider_);
    }

    function _validateAddressProviderInterface(
        address addressProvider_
    ) private view {
        if (addressProvider_.supportsInterface(AddressProviderInterfaceId))
            return;

        revert AddressIsNotAddressProvider(addressProvider_);
    }

    function addressProvider() public view returns (IMaatAddressProvider) {
        return _addressProvider;
    }
}
