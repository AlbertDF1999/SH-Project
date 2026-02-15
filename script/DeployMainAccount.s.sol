//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MainAccount} from "../src/MainAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
// import {MainAccountFactory} from "../src/MainAccountFactory.sol";

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

    /**
     * @notice Deploy factory and create an account
     * @dev This is the new recommended way to deploy accounts
     */
    // function deployMainAccountWithFactory()
    //     public
    //     returns (HelperConfig, MainAccountFactory, MainAccount)
    // {
    //     HelperConfig helperConfig = new HelperConfig();
    //     HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    //     vm.startBroadcast(config.account);

    //     // Deploy factory
    //     MainAccountFactory factory = new MainAccountFactory(
    //         IEntryPoint(config.entryPoint)
    //     );

    //     // Create account using factory with salt 0
    //     MainAccount mainAccount = factory.createAccount(config.account, 0);

    //     vm.stopBroadcast();

    //     return (helperConfig, factory, mainAccount);
    // }

    // /**
    //  * @notice Legacy deployment method (kept for backward compatibility)
    //  * @dev This creates accounts directly without factory - not recommended for production
    //  */
    // function deployMainAccount() public returns (HelperConfig, MainAccount) {
    //     HelperConfig helperConfig = new HelperConfig();
    //     HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    //     vm.startBroadcast(config.account);

    //     // Direct deployment (old way)
    //     MainAccount mainAccount = new MainAccount(config.entryPoint);
    //     mainAccount.initialize(config.account);

    //     vm.stopBroadcast();

    //     return (helperConfig, mainAccount);
    // }

    // /**
    //  * @notice Deploy only the factory
    //  * @dev Useful when you want to deploy factory once and create multiple accounts later
    //  */
    // function deployFactory() public returns (HelperConfig, MainAccountFactory) {
    //     HelperConfig helperConfig = new HelperConfig();
    //     HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

    //     vm.startBroadcast(config.account);
    //     MainAccountFactory factory = new MainAccountFactory(
    //         IEntryPoint(config.entryPoint)
    //     );
    //     vm.stopBroadcast();

    //     return (helperConfig, factory);
    // }
}
