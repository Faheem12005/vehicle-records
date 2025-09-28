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
    bytes32 constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 constant ROLE_MANAGER_ROLE = keccak256("ROLE_MANAGER_ROLE");
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        admin = address(0xABCD);
        user1 = address(0x1111);
        user2 = address(0x2222);

        // Deploy the actual VehicleRegistry
        registry = new VehicleRegistry();

        // Deploy RoleRequestManager with the real registry
        vm.prank(admin);
        manager = new RoleRequestManager(address(registry));

        // Grant ROLE_MANAGER_ROLE to the manager (not full admin!)
        registry.grantRole(ROLE_MANAGER_ROLE, address(manager));
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
        
        vm.expectRevert("Role not requestable");
        manager.requestRole(adminRole);
    }

    function testCannotRequestNonManageableRoles() public {
        vm.prank(user1);
        
        vm.expectRevert("Role not requestable");
        manager.requestRole(MINTER_ROLE);
    }

    function testCanRequestAllManageableRoles() public {
        // Test DEALER_ROLE
        vm.prank(user1);
        uint256 dealerRequestId = manager.requestRole(DEALER_ROLE);
        (address requester1, bytes32 role1, ) = manager.pendingRequests(dealerRequestId);
        assertEq(requester1, user1);
        assertEq(role1, DEALER_ROLE);

        // Test AUDITOR_ROLE
        vm.prank(user1);
        uint256 auditorRequestId = manager.requestRole(AUDITOR_ROLE);
        (address requester2, bytes32 role2, ) = manager.pendingRequests(auditorRequestId);
        assertEq(requester2, user1);
        assertEq(role2, AUDITOR_ROLE);

        // Test OWNER_ROLE
        vm.prank(user1);
        uint256 ownerRequestId = manager.requestRole(OWNER_ROLE);
        (address requester3, bytes32 role3, ) = manager.pendingRequests(ownerRequestId);
        assertEq(requester3, user1);
        assertEq(role3, OWNER_ROLE);
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

    function testOnlyAdminCanApproveRequests() public {
        vm.prank(user1);
        uint256 requestId = manager.requestRole(DEALER_ROLE);

        // Try to approve as non-admin
        vm.prank(user2);
        vm.expectRevert();
        manager.approveRoleRequest(requestId);

        // Admin should be able to approve
        vm.prank(admin);
        manager.approveRoleRequest(requestId);
        assertTrue(registry.hasRole(DEALER_ROLE, user1));
    }

    function testOnlyAdminCanDenyRequests() public {
        vm.prank(user1);
        uint256 requestId = manager.requestRole(DEALER_ROLE);

        // Try to deny as non-admin
        vm.prank(user2);
        vm.expectRevert();
        manager.denyRoleRequest(requestId);

        // Admin should be able to deny
        vm.prank(admin);
        manager.denyRoleRequest(requestId);
        (address requester, , ) = manager.pendingRequests(requestId);
        assertEq(requester, address(0));
    }

    function testAdminCanRevokeRoles() public {
        // First approve a role
        vm.prank(user1);
        uint256 requestId = manager.requestRole(DEALER_ROLE);

        vm.prank(admin);
        manager.approveRoleRequest(requestId);
        assertTrue(registry.hasRole(DEALER_ROLE, user1));

        // Admin can revoke the role
        vm.prank(admin);
        manager.revokeUserRole(DEALER_ROLE, user1);
        assertFalse(registry.hasRole(DEALER_ROLE, user1));
    }

    function testCannotRevokeNonManageableRoles() public {
        vm.prank(admin);
        vm.expectRevert("Role not manageable");
        manager.revokeUserRole(MINTER_ROLE, user1);
    }

    function testRoleManagerHasLimitedPermissions() public {
        // The manager should NOT be able to grant roles directly on the registry
        // that are not manageable
        vm.expectRevert();
        registry.grantManagedRole(MINTER_ROLE, user1);
    }

    function testRoleHierarchySetupCorrectly() public {
        // Check that the role admins are set correctly
        assertEq(registry.getRoleAdmin(DEALER_ROLE), ROLE_MANAGER_ROLE);
        assertEq(registry.getRoleAdmin(AUDITOR_ROLE), ROLE_MANAGER_ROLE);
        assertEq(registry.getRoleAdmin(OWNER_ROLE), ROLE_MANAGER_ROLE);
        assertEq(registry.getRoleAdmin(MINTER_ROLE), registry.DEFAULT_ADMIN_ROLE());
    }

    function testMultipleUsersCanRequestSameRole() public {
        // User1 requests DEALER_ROLE
        vm.prank(user1);
        uint256 requestId1 = manager.requestRole(DEALER_ROLE);

        // User2 requests DEALER_ROLE
        vm.prank(user2);
        uint256 requestId2 = manager.requestRole(DEALER_ROLE);

        // Both requests should be valid but separate
        (address requester1, bytes32 role1, ) = manager.pendingRequests(requestId1);
        (address requester2, bytes32 role2, ) = manager.pendingRequests(requestId2);

        assertEq(requester1, user1);
        assertEq(requester2, user2);
        assertEq(role1, DEALER_ROLE);
        assertEq(role2, DEALER_ROLE);

        // Approve both
        vm.prank(admin);
        manager.approveRoleRequest(requestId1);
        vm.prank(admin);
        manager.approveRoleRequest(requestId2);

        // Both should have the role
        assertTrue(registry.hasRole(DEALER_ROLE, user1));
        assertTrue(registry.hasRole(DEALER_ROLE, user2));
    }
}