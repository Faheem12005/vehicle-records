// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "./RoleRequestManager.sol";
import "./VehicleRegistry.sol";

contract RoleRequestManagerWithRegistryTest is Test {
    RoleRequestManager manager;
    VehicleRegistry registry;
    address admin;
    address user1;
    address user2;

    bytes32 constant DEALER_ROLE = keccak256("DEALER_ROLE");
    bytes32 constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    function setUp() public {
        admin = address(0xABCD);
        user1 = address(0x1111);
        user2 = address(0x2222);

        // Deploy the actual VehicleRegistry
        registry = new VehicleRegistry();

        // Deploy RoleRequestManager with the real registry
        vm.prank(admin);
        manager = new RoleRequestManager(address(registry));

        // Grant admin roles in registry if needed
        registry.grantRole(registry.DEFAULT_ADMIN_ROLE(), address(manager));
    }

    function testUserCanRequestRole() public {
        vm.prank(user1);
        uint256 requestId = manager.requestRole(DEALER_ROLE);

        (address requester, bytes32 role, bool approved) = manager.pendingRequests(requestId);
        assertEq(requester, user1);
        assertEq(role, DEALER_ROLE);
        assertEq(approved, false);
    }

    function testAdminCanApproveRoleRequest() public {
        vm.prank(user1);
        uint256 requestId = manager.requestRole(DEALER_ROLE);

        vm.prank(admin);
        manager.approveRoleRequest(requestId);

        // Check that request is marked approved
        (, , bool approved) = manager.pendingRequests(requestId);
        assertTrue(approved);

        // Check that role was granted in VehicleRegistry
        assertTrue(registry.hasRole(DEALER_ROLE, user1));
    }

    function testAdminCanDenyRoleRequest() public {
        vm.prank(user2);
        uint256 requestId = manager.requestRole(AUDITOR_ROLE);

        vm.prank(admin);
        manager.denyRoleRequest(requestId);

        // Check that request is removed
        (address requester, , ) = manager.pendingRequests(requestId);
        assertEq(requester, address(0));
    }

    function testCannotRequestAdminRole() public {
        vm.prank(user1);
        bytes32 adminRole = manager.DEFAULT_ADMIN_ROLE();
        vm.expectRevert("Cannot request admin role");
        manager.requestRole(adminRole);
    }

    function testCannotApproveTwice() public {
        vm.prank(user1);
        uint256 requestId = manager.requestRole(DEALER_ROLE);

        vm.prank(admin);
        manager.approveRoleRequest(requestId);

        vm.prank(admin);
        vm.expectRevert("Already processed");
        manager.approveRoleRequest(requestId);
    }
}
