//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {MainAccount} from "../src/MainAccount.sol";
import {Test} from "forge-std/Test.sol";
import {DeployMainAccount} from "../script/DeployMainAccount.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, MessageHashUtils, IEntryPoint} from "../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TestMainAccount is Test {
    using MessageHashUtils for bytes32;

    MainAccount mainAccount;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployMainAccount deployMain = new DeployMainAccount();
        (helperConfig, mainAccount) = deployMain.deployMainAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    //USDC MINT
    //USDC Approval
    //msg.sender => MainAccount
    //approve some amount
    //USDC Contract
    //come from the entrypoing

    function testOwnerCanExecuteCommands() public {
        //ARRANGE
        assertEq(usdc.balanceOf(address(mainAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
        //AcT
        vm.prank(mainAccount.owner());
        mainAccount.execute(dest, value, functionData);
        //ASSERT
        assertEq(usdc.balanceOf(address(mainAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        //ARRANGE
        assertEq(usdc.balanceOf(address(mainAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
        //AcT
        vm.prank(randomUser);
        vm.expectRevert(MainAccount.MainAccount__NotFromEntryPointorOwner.selector);
        mainAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        //arrange
        assertEq(usdc.balanceOf(address(mainAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(mainAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(mainAccount)
        );
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        //act
        address actualSigner = ECDSA.recover(digest, packedUserOp.signature);

        //assert
        assertEq(actualSigner, mainAccount.owner());
    }

    // sign user op
    // call validate user op
    // assert the return is correct
    function testValidateUserOp() public {
        //arrange
        assertEq(usdc.balanceOf(address(mainAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(mainAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(mainAccount)
        );
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        uint256 missingAccountFunds = 1e18;

        //Act
        vm.prank(helperConfig.getConfig().entryPoint);
        //we should parse the validation data since it has a lot of information
        uint256 validationDate = mainAccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        assertEq(validationDate, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        //arrange
        assertEq(usdc.balanceOf(address(mainAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(mainAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(mainAccount)
        );

        vm.deal(address(mainAccount), 1e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        //Act
        vm.startBroadcast(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));
        vm.stopBroadcast();
        //assert
        assertEq(usdc.balanceOf(address(mainAccount)), AMOUNT);
    }
}
