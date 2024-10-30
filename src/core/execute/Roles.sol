// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IRoles} from "../../interfaces/IExecutor.sol";

abstract contract Roles is Ownable, IRoles {
    address public commander;
    address public watcher;

    constructor(address commander_, address watcher_) {
        commander = commander_;
        watcher = watcher_;
    }

    event CommanderChanged(address prevCommander, address newCommander);

    function setCommander(address _commander) external onlyOwner {
        emit CommanderChanged(commander, _commander);

        commander = _commander;
    }

    event WatcherChanged(address prevWatcher, address newWatcher);

    function setWatcher(address _watcher) external onlyOwner {
        emit WatcherChanged(watcher, _watcher);

        watcher = _watcher;
    }

    /* ======== MODIFIERS ======== */

    modifier onlyCommanderOrAdmin() {
        require(
            msg.sender == commander || msg.sender == owner(),
            "MaatVaultV1: Caller is not commander or admin"
        );
        _;
    }

    modifier onlyWatcherOrAdmin() {
        require(
            msg.sender == watcher || msg.sender == owner(),
            "MaatVaultV1: Caller is not watcher or admin"
        );
        _;
    }
}
