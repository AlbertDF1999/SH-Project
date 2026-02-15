//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract MainAccount is IAccount, Ownable, Initializable {
    //////////ERRORS

    error MainAccount__NotFromEntryPoint();
    error MainAccount__NotFromEntryPointorOwner();
    error MainAccount__CallFailed(bytes);

    // error MainAccount__NotFromEntryPoint();
    // error MainAccount__NotFromEntryPointorOwner();
    // error MainAccount__CallFailed(bytes);
    // error MainAccount__InvalidArrayLength();
    // error MainAccount__SessionKeyNotValid();
    // error MainAccount__SessionKeyNotAuthorized();
    // error MainAccount__RecoveryNotInitiated();
    // error MainAccount__RecoveryPeriodNotPassed();
    // error MainAccount__OnlyGuardian();

    //////////EVENTS

    // event SessionKeyAdded(address indexed sessionKey, uint48 validUntil, address indexed target, bytes4 selector);
    // event SessionKeyRevoked(address indexed sessionKey);
    // event RecoveryInitiated(address indexed proposedOwner, uint256 executeAfter);
    // event RecoveryExecuted(address indexed newOwner);
    // event RecoveryCancelled();
    // event GuardianUpdated(address indexed oldGuardian, address indexed newGuardian);

    //////////STRUCTS

    // struct SessionKeyData {
    //     uint48 validUntil;
    //     uint48 validAfter;
    //     address target; // Address this key can call (address(0) = any)
    //     bytes4 selector; // Function this key can call (bytes4(0) = any)
    //     bool isActive;
    // }

    //////////STATE VARIABLES

    IEntryPoint private immutable i_entryPoint;

    // Session Keys

    // mapping(address => SessionKeyData) public sessionKeys;

    // Recovery

    // address public guardian;
    // uint256 public constant RECOVERY_PERIOD = 2 days;
    // address public proposedOwner;
    // uint256 public recoveryInitiated;

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

    //  modifier onlyGuardian() {
    //     if (msg.sender != guardian) {
    //         revert MainAccount__OnlyGuardian();
    //     }
    //     _;
    // }

    //////////FUNCTIONS

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
        _disableInitializers(); // Prevents initialization of implementation contract
    }

    /**
     * @notice Initialize the account - called by factory
     * @param anOwner The owner of this account
     */
    // function initialize(address anOwner) public initializer {
    //     _transferOwnership(anOwner);
    // }

    receive() external payable {}

    //////////EXTERNAL FUNCTIONS

    /**
     * @notice Execute a single transaction
     * @param dest The destination address
     * @param value The amount of ETH to send
     * @param functionData The calldata to execute
     */
    function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MainAccount__CallFailed(result);
        }
    }

    /**
     * @notice Execute multiple transactions in a single call
     * @param dest Array of destination addresses
     * @param values Array of ETH amounts to send
     * @param functionData Array of calldata to execute
     */
    // function executeBatch(
    //     address[] calldata dest,
    //     uint256[] calldata values,
    //     bytes[] calldata functionData
    // ) external requireFromEntryPointOrOwner {
    //     if (dest.length != values.length || values.length != functionData.length) {
    //         revert MainAccount__InvalidArrayLength();
    //     }

    //     for (uint256 i = 0; i < dest.length; i++) {
    //         (bool success, bytes memory result) = dest[i].call{value: values[i]}(functionData[i]);
    //         if (!success) {
    //             revert MainAccount__CallFailed(result);
    //         }
    //     }
    // }

    /**
     * @notice Validate a user operation
     * @param userOp The user operation to validate
     * @param userOpHash The hash of the user operation
     * @param missingAccountFunds The funds needed to execute the operation
     */
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

    //////////SESSION KEY FUNCTIONS

    /**
     * @notice Add a new session key with specific permissions
     * @param sessionKey The address of the session key
     * @param validUntil Timestamp when the key expires
     * @param target The contract this key can interact with (address(0) for any)
     * @param selector The function this key can call (bytes4(0) for any)
     */
    // function addSessionKey(
    //     address sessionKey,
    //     uint48 validUntil,
    //     address target,
    //     bytes4 selector
    // ) external onlyOwner {
    //     sessionKeys[sessionKey] = SessionKeyData({
    //         validUntil: validUntil,
    //         validAfter: uint48(block.timestamp),
    //         target: target,
    //         selector: selector,
    //         isActive: true
    //     });

    //     emit SessionKeyAdded(sessionKey, validUntil, target, selector);
    // }

    /**
     * @notice Revoke a session key
     * @param sessionKey The address of the session key to revoke
     */
    // function revokeSessionKey(address sessionKey) external onlyOwner {
    //     sessionKeys[sessionKey].isActive = false;
    //     emit SessionKeyRevoked(sessionKey);
    // }

    //////////RECOVERY FUNCTIONS

    /**
     * @notice Set or update the guardian address
     * @param newGuardian The address of the new guardian
     */
    // function setGuardian(address newGuardian) external onlyOwner {
    //     address oldGuardian = guardian;
    //     guardian = newGuardian;
    //     emit GuardianUpdated(oldGuardian, newGuardian);
    // }

    /**
     * @notice Initiate account recovery (guardian only)
     * @param newOwner The proposed new owner address
     */
    // function initiateRecovery(address newOwner) external onlyGuardian {
    //     proposedOwner = newOwner;
    //     recoveryInitiated = block.timestamp;
    //     emit RecoveryInitiated(newOwner, block.timestamp + RECOVERY_PERIOD);
    // }

    /**
     * @notice Execute account recovery after waiting period (guardian only)
     */
    // function executeRecovery() external onlyGuardian {
    //     if (recoveryInitiated == 0) {
    //         revert MainAccount__RecoveryNotInitiated();
    //     }
    //     if (block.timestamp < recoveryInitiated + RECOVERY_PERIOD) {
    //         revert MainAccount__RecoveryPeriodNotPassed();
    //     }

    //     address newOwner = proposedOwner;
    //     _transferOwnership(newOwner);

    //     // Reset recovery state
    //     proposedOwner = address(0);
    //     recoveryInitiated = 0;

    //     emit RecoveryExecuted(newOwner);
    // }

    /**
     * @notice Cancel an ongoing recovery (owner only)
     */
    // function cancelRecovery() external onlyOwner {
    //     proposedOwner = address(0);
    //     recoveryInitiated = 0;
    //     emit RecoveryCancelled();
    // }

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

    /**
     * @notice Validate the signature of a user operation
     * @dev Supports both owner signatures and session key signatures
     */
    // function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
    //     internal
    //     view
    //     returns (uint256 validationData)
    // {
    //     bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
    //     address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

    //     // Check if signer is the owner
    //     if (signer == owner()) {
    //         return SIG_VALIDATION_SUCCESS;
    //     }

    //     // Check if signer is a valid session key
    //     SessionKeyData memory sessionKey = sessionKeys[signer];

    //     if (!sessionKey.isActive) {
    //         return SIG_VALIDATION_FAILED;
    //     }

    //     // Check time validity
    //     if (block.timestamp < sessionKey.validAfter || block.timestamp > sessionKey.validUntil) {
    //         return SIG_VALIDATION_FAILED;
    //     }

    //     // Check target restriction
    //     if (sessionKey.target != address(0)) {
    //         address target = _getTargetFromCallData(userOp.callData);
    //         if (target != sessionKey.target) {
    //             return SIG_VALIDATION_FAILED;
    //         }
    //     }

    //     // Check selector restriction
    //     if (sessionKey.selector != bytes4(0)) {
    //         bytes4 selector = _getSelectorFromCallData(userOp.callData);
    //         if (selector != sessionKey.selector) {
    //             return SIG_VALIDATION_FAILED;
    //         }
    //     }

    //     return SIG_VALIDATION_SUCCESS;
    // }

    function _payPrefunds(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) =
                payable(address(i_entryPoint)).call{value: missingAccountFunds, gas: type(uint256).max}("");
            require(success, "Failed to pay prefund");
        }
    }

    /**
     * @notice Pay prefunds to the EntryPoint
     */
    // function _payPrefunds(uint256 missingAccountFunds) internal {
    //     if (missingAccountFunds != 0) {
    //         (bool success,) =
    //             payable(address(i_entryPoint)).call{value: missingAccountFunds, gas: type(uint256).max}("");
    //         require(success, "Failed to pay prefund");
    //     }
    // }

    /**
     * @notice Extract the target address from calldata
     * @dev Assumes calldata is for execute() or executeBatch()
     */
    // function _getTargetFromCallData(bytes calldata callData) internal pure returns (address) {
    //     if (callData.length < 4) {
    //         return address(0);
    //     }

    //     bytes4 selector = bytes4(callData[0:4]);

    //     // execute(address,uint256,bytes)
    //     if (selector == this.execute.selector) {
    //         if (callData.length < 36) {
    //             return address(0);
    //         }
    //         return address(uint160(uint256(bytes32(callData[4:36]))));
    //     }

    //     // executeBatch(address[],uint256[],bytes[])
    //     if (selector == this.executeBatch.selector) {
    //         // For batch, we just return address(0) to indicate "any target"
    //         // A more sophisticated implementation could check all targets
    //         return address(0);
    //     }

    //     return address(0);
    // }

    /**
     * @notice Extract the function selector from nested calldata
     * @dev Extracts selector from the execute() call's functionData parameter
     */
    // function _getSelectorFromCallData(bytes calldata callData) internal pure returns (bytes4) {
    //     if (callData.length < 4) {
    //         return bytes4(0);
    //     }

    //     bytes4 mainSelector = bytes4(callData[0:4]);

    //     // execute(address,uint256,bytes)
    //     if (mainSelector == this.execute.selector) {
    //         // Skip: selector(4) + address(32) + value(32) + offset(32) + length(32) = 132
    //         if (callData.length < 136) {
    //             return bytes4(0);
    //         }
    //         // The functionData starts at offset 132, and its selector is the first 4 bytes
    //         return bytes4(callData[132:136]);
    //     }

    //     return bytes4(0);
    // }

    //////////GETTERS

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }

    /**
     * @notice Check if a session key is currently valid
     * @param sessionKey The address to check
     */
    // function isSessionKeyValid(address sessionKey) external view returns (bool) {
    //     SessionKeyData memory key = sessionKeys[sessionKey];
    //     return key.isActive
    //         && block.timestamp >= key.validAfter
    //         && block.timestamp <= key.validUntil;
    // }

    /**
     * @notice Get session key data
     * @param sessionKey The address to query
     */
    // function getSessionKeyData(address sessionKey)
    //     external
    //     view
    //     returns (SessionKeyData memory)
    // {
    //     return sessionKeys[sessionKey];
    // }
}
