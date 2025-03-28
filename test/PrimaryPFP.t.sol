// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "ds-test/test.sol";
import "../src/PrimaryPFP.sol";
import "../src/IPrimaryPFP.sol";
import "../src/TestPFP.sol";
import "../lib/delegate-registry/src/DelegateRegistry.sol";

contract PrimaryPFPTest is Test {
    event PrimarySet(address indexed to, address indexed contract_, uint256 tokenId);

    event PrimarySetByDelegateCash(address indexed to, address indexed contract_, uint256 tokenId);

    event PrimaryRemoved(address indexed from, address indexed contract_, uint256 tokenId);

    DelegateRegistry dc;
    PrimaryPFP public ppfp;
    TestPFP public testPFP;
    TestPFP public testPFP1;
    address public testPFPAddress;
    address public testPFPAddress1;
    address public delegate;
    address contract_;
    uint256 tokenId;
    bytes32 rights;
    address[] pfpAddresses;

    function setUp() public {
        dc = new DelegateRegistry();
        ppfp = new PrimaryPFP();
        ppfp.initialize(address(dc));
        testPFP = new TestPFP("Test PFP", "TPFP");
        testPFP1 = new TestPFP("Test PFP1", "TPFP1");
        testPFPAddress = address(testPFP);
        testPFPAddress1 = address(testPFP1);
        delegate = makeAddr("delegate");
        vm.prank(msg.sender);
        testPFP.mint(0);
        rights = bytes32(0);
        pfpAddresses.push(testPFPAddress);
    }

    function _setPrimaryPFP(uint256 _tokenId) internal {
        vm.prank(msg.sender);
        ppfp.setPrimary(testPFPAddress, _tokenId);
    }

    function testSetNotFromSender() public {
        vm.expectRevert(PrimaryPFP.MsgSenderNotOwner.selector);
        ppfp.setPrimary(testPFPAddress, 0);
    }

    function testDuplicatedSet() public {
        _setPrimaryPFP(0);
        vm.expectRevert(PrimaryPFP.PrimaryDuplicateSet.selector);
        _setPrimaryPFP(0);
    }

    function testGetPrimaryEmpty() public {
        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, address(0));
        assertEq(pfp.tokenId, 0);
    }

    function testGetPrimary() public {
        _setPrimaryPFP(0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);
    }

    function testGetVerifiedPrimary() public {
        _setPrimaryPFP(0);
        vm.prank(tx.origin);
        ppfp.addVerification(pfpAddresses);
        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);
        assertTrue(pfp.isCollectionVerified);
    }

    function testGetPrimaries() public {
        _setPrimaryPFP(0);

        vm.prank(delegate);
        testPFP1.mint(1);

        vm.prank(delegate);
        ppfp.setPrimary(testPFPAddress1, 1);

        address[] memory addrs = new address[](3);
        addrs[0] = msg.sender;
        addrs[1] = address(0);
        addrs[2] = delegate;
        IPrimaryPFP.PFP[] memory result = ppfp.getPrimaries(addrs);

        assertEq(result[0].contract_, testPFPAddress);
        assertEq(result[0].tokenId, 0);

        assertEq(result[1].contract_, address(0));
        assertEq(result[1].tokenId, 0);

        assertEq(result[2].contract_, testPFPAddress1);
        assertEq(result[2].tokenId, 1);
    }

    function testGetPrimarySetAddressNotSet() public {
        address addr = ppfp.getPrimaryAddress(testPFPAddress, 0);
        assertEq(addr, address(0));
    }

    function testSetPrimaryPFP() public {
        _setPrimaryPFP(0);

        vm.prank(msg.sender);
        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(pfp.contract_, pfp.tokenId);
        assertEq(addr, msg.sender);
    }

    function testEventForSetPrimary() public {
        vm.prank(msg.sender);
        vm.expectEmit(true, true, false, true);
        emit PrimarySet(msg.sender, testPFPAddress, 0);
        ppfp.setPrimary(testPFPAddress, 0);
    }

    function testSetPrimaryPFPByDelegateCashNotDelegated() public {
        vm.expectRevert(PrimaryPFP.MsgSenderNotDelegated.selector);
        ppfp.setPrimaryByDelegateCash(testPFPAddress, 0);
    }

    function testSetPrimaryPFPByDelegateCashToken() public {
        vm.prank(msg.sender);

        dc.delegateERC721(delegate, testPFPAddress, 0, rights, true);
        assertTrue(dc.checkDelegateForERC721(delegate, msg.sender, testPFPAddress, 0, rights));

        vm.prank(delegate);
        emit PrimarySetByDelegateCash(msg.sender, testPFPAddress, 0);
        ppfp.setPrimaryByDelegateCash(testPFPAddress, 0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(delegate);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(pfp.contract_, pfp.tokenId);
        assertEq(addr, delegate);
    }

    function testSetPrimaryPFPByDelegateCashContract() public {
        vm.prank(msg.sender);

        dc.delegateContract(delegate, testPFPAddress, rights, true);
        assertTrue(dc.checkDelegateForContract(delegate, msg.sender, testPFPAddress, rights));

        vm.prank(delegate);
        ppfp.setPrimaryByDelegateCash(testPFPAddress, 0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(delegate);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(pfp.contract_, pfp.tokenId);
        assertEq(addr, delegate);
    }

    function testSetPrimaryPFPByDelegateCashAll() public {
        vm.prank(msg.sender);

        dc.delegateAll(delegate, rights, true);
        assertTrue(dc.checkDelegateForAll(delegate, msg.sender, rights));

        vm.prank(delegate);
        ppfp.setPrimaryByDelegateCash(testPFPAddress, 0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(delegate);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(pfp.contract_, pfp.tokenId);
        assertEq(addr, delegate);
    }

    function testSetOverrideByNewPFP() public {
        _setPrimaryPFP(0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        testPFP.mint(1);
        _setPrimaryPFP(1);

        vm.prank(msg.sender);
        pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 1);

        _setPrimaryPFP(0);

        pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(tokenId, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(pfp.contract_, pfp.tokenId);
        assertEq(addr, msg.sender);
    }

    function testSetOverrideBySameOwner() public {
        _setPrimaryPFP(0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        testPFP.mint(1);

        vm.expectEmit(true, true, true, true);
        emit PrimaryRemoved(msg.sender, testPFPAddress, 0);

        vm.expectEmit(true, true, true, true);
        emit PrimarySet(msg.sender, testPFPAddress, 1);

        _setPrimaryPFP(1);

        vm.prank(msg.sender);
        pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 1);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(pfp.contract_, pfp.tokenId);
        assertEq(addr, msg.sender);
    }

    function testRemovePrimaryFromTwoAddresses() public {
        _setPrimaryPFP(0);

        vm.prank(delegate);
        testPFP.mint(1);

        vm.prank(delegate);
        ppfp.setPrimary(testPFPAddress, 1);

        vm.prank(delegate);
        IERC721(testPFPAddress).transferFrom(delegate, msg.sender, 1);

        assertEq(IERC721(testPFPAddress).ownerOf(1), msg.sender);
        vm.expectEmit(true, true, true, true);
        emit PrimaryRemoved(msg.sender, testPFPAddress, 0);

        vm.expectEmit(true, true, true, true);
        emit PrimaryRemoved(delegate, testPFPAddress, 1);

        vm.expectEmit(true, true, true, true);
        emit PrimarySet(msg.sender, testPFPAddress, 1);

        _setPrimaryPFP(1);

        vm.prank(msg.sender);
        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 1);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(pfp.contract_, pfp.tokenId);
        assertEq(addr, msg.sender);
    }

    function testSetOverrideByNewOwner() public {
        _setPrimaryPFP(0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        IERC721(testPFPAddress).transferFrom(msg.sender, delegate, 0);

        vm.prank(delegate);
        vm.deal(delegate, 1 ether);

        ppfp.setPrimary(testPFPAddress, 0);

        vm.prank(msg.sender);
        pfp = ppfp.getPrimary(delegate);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(testPFPAddress, 0);
        assertEq(addr, delegate);
    }

    function testSetOverrideBySameAddress() public {
        _setPrimaryPFP(0);

        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        testPFP.mint(1);
        _setPrimaryPFP(1);

        vm.prank(msg.sender);
        pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, testPFPAddress);
        assertEq(pfp.tokenId, 1);
    }

    function testRemoveFromWrongSender() public {
        vm.expectRevert(PrimaryPFP.MsgSenderNotOwner.selector);
        vm.prank(delegate);
        ppfp.removePrimary(testPFPAddress, 0);
    }

    function testRemoveFromAddressNotSet() public {
        vm.expectRevert(PrimaryPFP.PrimaryNotSet.selector);
        vm.prank(msg.sender);
        ppfp.removePrimary(testPFPAddress, 0);
    }

    function testRemovePrimary() public {
        _setPrimaryPFP(0);

        vm.prank(msg.sender);
        vm.expectEmit(true, true, false, true);
        emit PrimaryRemoved(msg.sender, testPFPAddress, 0);
        ppfp.removePrimary(testPFPAddress, 0);

        vm.prank(msg.sender);
        IPrimaryPFP.PFP memory pfp = ppfp.getPrimary(msg.sender);
        assertEq(pfp.contract_, address(0));
        assertEq(pfp.tokenId, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(testPFPAddress, 0);
        assertEq(addr, address(0));
    }

    function testSetAddressNotOwner() public {
        _setPrimaryPFP(0);

        vm.prank(msg.sender);
        IERC721(testPFPAddress).transferFrom(msg.sender, delegate, 0);

        vm.prank(msg.sender);
        address addr = ppfp.getPrimaryAddress(testPFPAddress, 0);

        assertEq(IERC721(testPFPAddress).ownerOf(0), delegate);
        assertTrue(addr != delegate);
    }
}
