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

        vm.deal(address(mainAccount), 1e18);

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

    // using MessageHashUtils for bytes32;

    // MainAccount mainAccount;
    // MainAccountFactory factory;
    // HelperConfig helperConfig;
    // ERC20Mock usdc;
    // SendPackedUserOp sendPackedUserOp;

    // uint256 constant AMOUNT = 1e18;
    // address randomUser = makeAddr("randomUser");
    // address guardian = makeAddr("guardian");
    
    // // Session key test addresses
    // address sessionKeyAddr = makeAddr("sessionKey");
    // uint256 sessionKeyPrivateKey = 0x1234567890abcdef;

    // function setUp() public {
    //     DeployMainAccount deployMain = new DeployMainAccount();
    //     (helperConfig, factory, mainAccount) = deployMain.deployMainAccountWithFactory();
    //     usdc = new ERC20Mock();
    //     sendPackedUserOp = new SendPackedUserOp();
        
    //     // Set up guardian
    //     vm.prank(mainAccount.owner());
    //     mainAccount.setGuardian(guardian);
    // }

    // //////////BASIC EXECUTION TESTS

    // function testOwnerCanExecuteCommands() public {
    //     //ARRANGE
    //     assertEq(usdc.balanceOf(address(mainAccount)), 0);
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
        
    //     //ACT
    //     vm.prank(mainAccount.owner());
    //     mainAccount.execute(dest, value, functionData);
        
    //     //ASSERT
    //     assertEq(usdc.balanceOf(address(mainAccount)), AMOUNT);
    // }

    // function testNonOwnerCannotExecuteCommands() public {
    //     //ARRANGE
    //     assertEq(usdc.balanceOf(address(mainAccount)), 0);
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
        
    //     //ACT
    //     vm.prank(randomUser);
    //     vm.expectRevert(MainAccount.MainAccount__NotFromEntryPointorOwner.selector);
    //     mainAccount.execute(dest, value, functionData);
    // }

    // //////////BATCH EXECUTION TESTS

    // function testBatchExecution() public {
    //     //ARRANGE
    //     address[] memory destinations = new address[](2);
    //     uint256[] memory values = new uint256[](2);
    //     bytes[] memory functionDataArray = new bytes[](2);

    //     destinations[0] = address(usdc);
    //     destinations[1] = address(usdc);
    //     values[0] = 0;
    //     values[1] = 0;
    //     functionDataArray[0] = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
    //     functionDataArray[1] = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);

    //     //ACT
    //     vm.prank(mainAccount.owner());
    //     mainAccount.executeBatch(destinations, values, functionDataArray);

    //     //ASSERT
    //     assertEq(usdc.balanceOf(address(mainAccount)), AMOUNT * 2);
    // }

    // function testBatchExecutionRevertsOnInvalidArrayLength() public {
    //     //ARRANGE
    //     address[] memory destinations = new address[](2);
    //     uint256[] memory values = new uint256[](1); // Mismatched length
    //     bytes[] memory functionDataArray = new bytes[](2);

    //     //ACT & ASSERT
    //     vm.prank(mainAccount.owner());
    //     vm.expectRevert(MainAccount.MainAccount__InvalidArrayLength.selector);
    //     mainAccount.executeBatch(destinations, values, functionDataArray);
    // }

    // //////////SESSION KEY TESTS

    // function testAddSessionKey() public {
    //     //ARRANGE
    //     uint48 validUntil = uint48(block.timestamp + 1 days);
    //     address target = address(usdc);
    //     bytes4 selector = ERC20Mock.transfer.selector;

    //     //ACT
    //     vm.prank(mainAccount.owner());
    //     mainAccount.addSessionKey(sessionKeyAddr, validUntil, target, selector);

    //     //ASSERT
    //     MainAccount.SessionKeyData memory sessionKey = mainAccount.getSessionKeyData(sessionKeyAddr);
    //     assertEq(sessionKey.validUntil, validUntil);
    //     assertEq(sessionKey.target, target);
    //     assertEq(sessionKey.selector, selector);
    //     assertTrue(sessionKey.isActive);
    //     assertTrue(mainAccount.isSessionKeyValid(sessionKeyAddr));
    // }

    // function testRevokeSessionKey() public {
    //     //ARRANGE
    //     uint48 validUntil = uint48(block.timestamp + 1 days);
        
    //     vm.prank(mainAccount.owner());
    //     mainAccount.addSessionKey(sessionKeyAddr, validUntil, address(0), bytes4(0));
        
    //     assertTrue(mainAccount.isSessionKeyValid(sessionKeyAddr));

    //     //ACT
    //     vm.prank(mainAccount.owner());
    //     mainAccount.revokeSessionKey(sessionKeyAddr);

    //     //ASSERT
    //     assertFalse(mainAccount.isSessionKeyValid(sessionKeyAddr));
    // }

    // function testSessionKeyExpiration() public {
    //     //ARRANGE
    //     uint48 validUntil = uint48(block.timestamp + 1 hours);
        
    //     vm.prank(mainAccount.owner());
    //     mainAccount.addSessionKey(sessionKeyAddr, validUntil, address(0), bytes4(0));
        
    //     assertTrue(mainAccount.isSessionKeyValid(sessionKeyAddr));

    //     //ACT - Move time forward past expiration
    //     vm.warp(block.timestamp + 2 hours);

    //     //ASSERT
    //     assertFalse(mainAccount.isSessionKeyValid(sessionKeyAddr));
    // }

    // //////////RECOVERY TESTS

    // function testInitiateRecovery() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");

    //     //ACT
    //     vm.prank(guardian);
    //     mainAccount.initiateRecovery(newOwner);

    //     //ASSERT
    //     assertEq(mainAccount.proposedOwner(), newOwner);
    //     assertEq(mainAccount.recoveryInitiated(), block.timestamp);
    // }

    // function testExecuteRecoveryAfterPeriod() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");
    //     address oldOwner = mainAccount.owner();
        
    //     vm.prank(guardian);
    //     mainAccount.initiateRecovery(newOwner);

    //     //ACT - Wait for recovery period
    //     vm.warp(block.timestamp + mainAccount.RECOVERY_PERIOD() + 1);
        
    //     vm.prank(guardian);
    //     mainAccount.executeRecovery();

    //     //ASSERT
    //     assertEq(mainAccount.owner(), newOwner);
    //     assertNotEq(mainAccount.owner(), oldOwner);
    //     assertEq(mainAccount.proposedOwner(), address(0));
    //     assertEq(mainAccount.recoveryInitiated(), 0);
    // }

    // function testCannotExecuteRecoveryBeforePeriod() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");
        
    //     vm.prank(guardian);
    //     mainAccount.initiateRecovery(newOwner);

    //     //ACT & ASSERT - Try to execute too early
    //     vm.prank(guardian);
    //     vm.expectRevert(MainAccount.MainAccount__RecoveryPeriodNotPassed.selector);
    //     mainAccount.executeRecovery();
    // }

    // function testOwnerCanCancelRecovery() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");
        
    //     vm.prank(guardian);
    //     mainAccount.initiateRecovery(newOwner);

    //     //ACT
    //     vm.prank(mainAccount.owner());
    //     mainAccount.cancelRecovery();

    //     //ASSERT
    //     assertEq(mainAccount.proposedOwner(), address(0));
    //     assertEq(mainAccount.recoveryInitiated(), 0);
    // }

    // function testNonGuardianCannotInitiateRecovery() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");

    //     //ACT & ASSERT
    //     vm.prank(randomUser);
    //     vm.expectRevert(MainAccount.MainAccount__OnlyGuardian.selector);
    //     mainAccount.initiateRecovery(newOwner);
    // }

    // //////////FACTORY TESTS

    // function testFactoryCreatesAccount() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");
    //     uint256 salt = 123;

    //     //ACT
    //     MainAccount newAccount = factory.createAccount(newOwner, salt);

    //     //ASSERT
    //     assertEq(newAccount.owner(), newOwner);
    //     assertEq(address(newAccount.getEntryPoint()), address(helperConfig.getConfig().entryPoint));
    // }

    // function testFactoryComputesCorrectAddress() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");
    //     uint256 salt = 456;

    //     //ACT
    //     address predictedAddress = factory.getAddress(newOwner, salt);
    //     MainAccount newAccount = factory.createAccount(newOwner, salt);

    //     //ASSERT
    //     assertEq(address(newAccount), predictedAddress);
    // }

    // function testFactoryIdempotent() public {
    //     //ARRANGE
    //     address newOwner = makeAddr("newOwner");
    //     uint256 salt = 789;

    //     //ACT
    //     MainAccount account1 = factory.createAccount(newOwner, salt);
    //     MainAccount account2 = factory.createAccount(newOwner, salt);

    //     //ASSERT
    //     assertEq(address(account1), address(account2));
    // }

    // //////////EXISTING TESTS (updated for new structure)

    // function testRecoverSignedOp() public {
    //     //ARRANGE
    //     assertEq(usdc.balanceOf(address(mainAccount)), 0);
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
    //     bytes memory executeCallData = abi.encodeWithSelector(mainAccount.execute.selector, dest, value, functionData);
    //     PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
    //         executeCallData, helperConfig.getConfig(), address(mainAccount)
    //     );
    //     bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
    //     bytes32 digest = userOpHash.toEthSignedMessageHash();

    //     //ACT
    //     address actualSigner = ECDSA.recover(digest, packedUserOp.signature);

    //     //ASSERT
    //     assertEq(actualSigner, mainAccount.owner());
    // }

    // function testValidateUserOp() public {
    //     //ARRANGE
    //     assertEq(usdc.balanceOf(address(mainAccount)), 0);
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
    //     bytes memory executeCallData = abi.encodeWithSelector(mainAccount.execute.selector, dest, value, functionData);
    //     PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
    //         executeCallData, helperConfig.getConfig(), address(mainAccount)
    //     );
    //     bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
    //     uint256 missingAccountFunds = 1e18;

    //     vm.deal(address(mainAccount), 1e18);

    //     //ACT
    //     vm.prank(helperConfig.getConfig().entryPoint);
    //     uint256 validationData = mainAccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        
    //     //ASSERT
    //     assertEq(validationData, 0);
    // }

    // function testEntryPointCanExecuteCommands() public {
    //     //ARRANGE
    //     assertEq(usdc.balanceOf(address(mainAccount)), 0);
    //     address dest = address(usdc);
    //     uint256 value = 0;
    //     bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(mainAccount), AMOUNT);
    //     bytes memory executeCallData = abi.encodeWithSelector(mainAccount.execute.selector, dest, value, functionData);
    //     PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
    //         executeCallData, helperConfig.getConfig(), address(mainAccount)
    //     );

    //     vm.deal(address(mainAccount), 1e18);

    //     PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    //     ops[0] = packedUserOp;

    //     //ACT
    //     vm.prank(randomUser);
    //     IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));
        
    //     //ASSERT
    //     assertEq(usdc.balanceOf(address(mainAccount)), AMOUNT);
    // }
}
