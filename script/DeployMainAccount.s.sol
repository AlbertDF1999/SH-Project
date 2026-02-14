//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MainAccount} from "../src/MainAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMainAccount is Script {
    function run() public {}

    function deployMainAccount() public returns (HelperConfig, MainAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        MainAccount mainAccount = new MainAccount(config.entryPoint);
        mainAccount.transferOwnership(config.account);
        vm.stopBroadcast();
        return (helperConfig, mainAccount);
    }
}
