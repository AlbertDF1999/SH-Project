//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MainAccount is IAccount, Ownable {
    //////////ERRORS

    error MainAccount__NotFromEntryPoint();
    error MainAccount__NotFromEntryPointorOwner();
    error MainAccount__CallFailed(bytes);

    //////////STATE VARIABLES

    IEntryPoint private immutable i_entryPoint;

    //////////MODIFIERS

    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MainAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MainAccount__NotFromEntryPointorOwner();
        }
        _;
    }

    //////////FUNCTIONS

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    //////////EXTERNAL FUNCTIONS

    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MainAccount__CallFailed(result);
        }
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        //_validateNonce
        //pay the entry point
        _payPrefunds(missingAccountFunds);
    }

    //////////INTERNAL FUNCTIONS

    //EIP-191 version of the signed hash (MessageHashUtils)
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefunds(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) =
                payable(address(i_entryPoint)).call{value: missingAccountFunds, gas: type(uint256).max}("");
            require(success, "Failed to pay prefund");
        }
    }

    //////////GETTERS

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
