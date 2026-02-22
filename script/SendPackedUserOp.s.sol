//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MainAccount} from "../src/MainAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() public {}

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address mainAccount
    ) public returns (PackedUserOperation memory) {
        //generate unsigned data
        // uint256 nonce = vm.getNonce(config.account) - 1;
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(address(mainAccount), 0);
        // uint256 nonce = 0;
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(callData, mainAccount, nonce);

        //get the userop hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        //sign it, and return it
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(vm.envUint("PRIVATE_KEY"), digest);
        }

        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        // Before executing your UserOp, the EntryPoint needs a deposit from your smart account to cover potential gas costs. Here's how it was calculated:
        // The formula: prefund = (verificationGasLimit + callGasLimit + preVerificationGas) × maxFeePerGas
        // So: (500,000 + 500,000 + 100,000) × 1,000,000 = 1,100,000,000,000 wei = 0.0000011 ETH
        // This is the amount your MainAccount sent to the EntryPoint during validateUserOp via _payPrefunds. You can see it in the trace:
        // EntryPoint::receive{value: 1100000000000}
        // emit Deposited(account: MainAccount, totalDeposit: 1100000000000)
        uint128 verificationGasLimit = 500000;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 100000;
        uint128 maxFeePerGas = 1000000;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: 100000,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
