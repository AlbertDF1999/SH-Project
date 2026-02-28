//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {MainAccount} from "./MainAccount.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

/**
 * @title MainAccountFactory
 * @notice Factory contract for creating MainAccount instances using CREATE2
 * @dev Uses the ERC1967 proxy pattern for gas-efficient deployments
 */
contract MainAccountFactory {
    //////////ERRORS
    error MainAccountFactory__AccountAlreadyExists();

    //////////EVENTS
    event AccountCreated(address indexed account, address indexed owner, uint256 salt);

    //////////STATE VARIABLES
    MainAccount public immutable accountImplementation;
    IEntryPoint public immutable entryPoint;

    //////////FUNCTIONS

    /**
     * @notice Constructor
     * @param _entryPoint The EntryPoint contract address
     */
    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
        accountImplementation = new MainAccount(address(_entryPoint));
    }

    /**
     * @notice Create a new account (idempotent)
     * @dev Uses CREATE2 for deterministic addresses
     * @param owner The owner of the new account
     * @param salt A unique value to generate different addresses for the same owner
     * @return account The created (or existing) MainAccount
     */
    function createAccount(address owner, uint256 salt) external returns (MainAccount) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;

        // If account already exists, return it
        if (codeSize > 0) {
            return MainAccount(payable(addr));
        }

        // Deploy new proxy pointing to implementation
        bytes memory initData = abi.encodeCall(MainAccount.initialize, (owner));

        ERC1967Proxy proxy = new ERC1967Proxy{salt: bytes32(salt)}(address(accountImplementation), initData);

        emit AccountCreated(address(proxy), owner, salt);

        return MainAccount(payable(address(proxy)));
    }

    /**
     * @notice Compute the counterfactual address of an account
     * @dev Useful for getting the address before deployment
     * @param owner The owner of the account
     * @param salt The salt used for CREATE2
     * @return The computed address
     */
    function getAddress(address owner, uint256 salt) public view returns (address) {
        bytes memory initData = abi.encodeCall(MainAccount.initialize, (owner));

        bytes memory proxyBytecode =
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(accountImplementation), initData));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(salt), keccak256(proxyBytecode)));

        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Add stake for the factory in the EntryPoint
     * @dev Required for factory to be used by bundlers
     * @param unstakeDelaySec The delay before unstaking
     */
    function addStake(uint32 unstakeDelaySec) external payable {
        entryPoint.addStake{value: msg.value}(unstakeDelaySec);
    }

    /**
     * @notice Unlock stake in the EntryPoint
     */
    function unlockStake() external {
        entryPoint.unlockStake();
    }

    /**
     * @notice Withdraw stake from the EntryPoint
     * @param withdrawAddress The address to receive the stake
     */
    function withdrawStake(address payable withdrawAddress) external {
        entryPoint.withdrawStake(withdrawAddress);
    }
}
