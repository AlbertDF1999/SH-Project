//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MainAccount} from "../src/MainAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SendPackedUserOp} from "./SendPackedUserOp.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract SendUserOpSepolia is Script {
    using MessageHashUtils for bytes32;

    function run() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address mainAccountAddr = 0x1DA62d49D8bbd8Fbe879dD7aACa7153914c47363;

        // Build calldata: send 0.001 ETH back to your wallet
        bytes memory executeCallData = abi.encodeWithSelector(
            MainAccount.execute.selector,
            config.account, // destination: your wallet
            0.001 ether, // value
            "" // no calldata (simple ETH transfer)
        );

        // Generate signed UserOp
        SendPackedUserOp sendPackedUserOp = new SendPackedUserOp();
        PackedUserOperation memory userOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config, mainAccountAddr);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // Send it through the EntryPoint
        vm.startBroadcast();
        IEntryPoint(config.entryPoint).handleOps(ops, payable(config.account));
        vm.stopBroadcast();
    }
}
