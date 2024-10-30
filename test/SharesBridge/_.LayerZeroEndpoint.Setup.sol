// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EndpointV2Mock} from "@layerzerolabs/test-devtools-evm-foundry/contracts/mocks/EndpointV2Mock.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract LayerZeroHelper is TestHelperOz5 {
    EndpointV2Mock endPointA;
    EndpointV2Mock endPointB;
    EndpointV2Mock endPointC;

    uint32 eidA = 1;
    uint32 eidB = 2;
    uint32 eidC = 3;

    function setUpEndpoints() public {
        setUpEndpoints(3, TestHelperOz5.LibraryType.UltraLightNode);

        //enum starts with 1 because inside LZ lib we skip 0 step of iteration
        endPointA = EndpointV2Mock(endpoints[1]);
        endPointB = EndpointV2Mock(endpoints[2]);
        endPointC = EndpointV2Mock(endpoints[3]);
    }
}
