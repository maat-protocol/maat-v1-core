// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OAppOptionsType3} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";

import {MessagingReceipt} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

import {IMaatAddressProvider} from "../interfaces/IMaatAddressProvider.sol";
import {IMaatSharesBridge} from "../interfaces/IMaatSharesBridge.sol";
import {IMaatVaultV1} from "../interfaces/IMaatVaultV1.sol";

import {AddressProviderKeeper} from "../core/base/AddressProviderKeeper.sol";

contract MaatSharesBridge is
    OApp,
    IMaatSharesBridge,
    OAppOptionsType3,
    AddressProviderKeeper
{
    constructor(
        address _maatAddressProvider,
        address _endpoint,
        address _delegate
    )
        OApp(_endpoint, _delegate)
        Ownable(_delegate)
        AddressProviderKeeper(_maatAddressProvider)
    {}

    function bridge(
        uint32 _dstEid,
        BridgeData memory data,
        bytes calldata _options
    ) external payable onlyMaatVault {
        // Encode the data before invoking _lzSend.
        bytes memory _payload = abi.encode(data);
        MessagingReceipt memory _receipt = _lzSend(
            _dstEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0),
            data.user
        );

        emit SendShares(
            _receipt.guid,
            data.user,
            msg.sender,
            data.targetVault,
            data.amount,
            _dstEid
        );
    }

    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address _executor, // Executor address as specified by the OApp.
        bytes calldata _extraData // Any extra data or options to trigger on receipt.
    ) internal override {
        // Decode the payload to get the message
        // In this case, type is string, but depends on your encoding!
        BridgeData memory data = abi.decode(payload, (BridgeData));

        IMaatVaultV1(data.targetVault).finishSharesBridge(
            data.user,
            data.amount
        );

        emit ReceiveShares(_guid, data.user, data.targetVault, data.amount);
    }

    /* @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @return nativeFee Estimated gas fee in native gas.
     * @return lzTokenFee Estimated gas fee in ZRO token.
     */
    function quote(
        uint32 _dstEid, // Destination chain's endpoint ID.
        BridgeData memory data, // The message to send.
        bytes calldata _options, // Message execution options
        bool _payInLzToken
    ) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        bytes memory _payload = abi.encode(data);
        MessagingFee memory fee = _quote(
            _dstEid,
            _payload,
            _options,
            _payInLzToken
        );
        return (fee.nativeFee, fee.lzTokenFee);
    }

    modifier onlyMaatVault() {
        if (!addressProvider().isVault(msg.sender)) revert NotMaatVault();

        _;
    }
}
