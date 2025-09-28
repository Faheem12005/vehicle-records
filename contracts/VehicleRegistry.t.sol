// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {VehicleRegistry} from "./VehicleRegistry.sol";
import {IVehicleRegistry, VehicleStatus} from "./interfaces/IVehicleRegistry.sol";
import {Test} from "forge-std/Test.sol";

contract VehicleRegistryTest is Test {
    VehicleRegistry vehicleRegistry;
    
    address admin = address(0x1);
    address dealer = address(0x3);
    address owner = address(0x4);
    address auditor = address(0x5);
    address unauthorizedUser = address(0x6);
    
    bytes32 constant DEALER_ROLE = keccak256("DEALER_ROLE");
    bytes32 constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 constant ROLE_MANAGER_ROLE = keccak256("ROLE_MANAGER_ROLE");

    function setUp() public {
        vm.prank(admin);
        vehicleRegistry = new VehicleRegistry();
        
        // Grant roles using the admin account
        vm.startPrank(admin);
        vehicleRegistry.grantRole(DEALER_ROLE, dealer);
        vehicleRegistry.grantRole(OWNER_ROLE, owner);
        vehicleRegistry.grantRole(AUDITOR_ROLE, auditor);
        vm.stopPrank();
    }

    function test_RequestRegistration() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123", // IPFS hash
            owner
        );
        vm.prank(dealer);
        IVehicleRegistry.VehicleRegistration memory registration = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);
        
        assertEq(registration.ownerAddress, owner);
        assertEq(registration.requesterAddress, dealer);
        assertEq(uint256(registration.status), uint256(VehicleStatus.Pending));
        assertEq(registration.minted, false);
        assertEq(registration.registrationDate, 0); // Should be 0 until approved
        assertEq(registration.issuerAddress, address(0)); // Should be 0 until approved
    }

    function test_ApproveRegistration() public {
        // First, request registration
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        // Auditor approves with certificate IPFS hash
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash123");

        // Check registration details
        vm.prank(owner); // Only owner can fetch their registration
        IVehicleRegistry.VehicleRegistration memory registration = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);
        assertEq(uint256(registration.status), uint256(VehicleStatus.Approved));
        assertEq(registration.minted, true);
        assertEq(registration.registrationDate, block.timestamp);
        assertEq(registration.issuerAddress, auditor);

        // Check that NFT was minted to the owner
        assertEq(vehicleRegistry.ownerOf(0), owner); // First token should be owned by owner
        assertEq(vehicleRegistry.balanceOf(owner), 1); // Owner should have 1 token

        // Check certificate details
        vm.prank(owner); // Only owner can fetch their certificate
        IVehicleRegistry.VehicleCertificate memory certificate = vehicleRegistry.fetchVehicleCertificate(0);
        assertEq(certificate.ownerAddress, registration.ownerAddress);
        assertEq(certificate.issuerAddress, registration.issuerAddress);
        assertEq(certificate.certIpfsHash, "QmCertHash123");
        assertEq(certificate.registrationDate, block.timestamp);
    }

    function test_DenyRegistration() public {
        // Request registration
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        // Auditor denies registration
        vm.prank(auditor);
        vehicleRegistry.denyVehicleRegistration(requestId, "Invalid documentation");

        // Check registration was denied
        vm.prank(owner);
        IVehicleRegistry.VehicleRegistration memory registration = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);
        assertEq(uint256(registration.status), uint256(VehicleStatus.Rejected));
        assertEq(registration.minted, false);
        assertEq(registration.registrationDate, block.timestamp); // Timestamp of denial
        assertEq(registration.issuerAddress, auditor); // Auditor who denied it

        // Check no NFT was minted
        assertEq(vehicleRegistry.balanceOf(owner), 0);
    }

    function test_FetchRegistrationRequest_Authorization() public {
        // Setup: create a registration request
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        // Requester (dealer) should be able to view
        vm.prank(dealer);
        IVehicleRegistry.VehicleRegistration memory reg1 = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);
        assertEq(reg1.requesterAddress, dealer);

        // Owner should be able to view
        vm.prank(owner);
        IVehicleRegistry.VehicleRegistration memory reg2 = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);
        assertEq(reg2.ownerAddress, owner);

        // Auditor should be able to view (has AUDITOR_ROLE)
        vm.prank(auditor);
        IVehicleRegistry.VehicleRegistration memory reg3 = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);
        assertEq(reg3.ownerAddress, owner);

        // Unauthorized user should not be able to view
        vm.prank(unauthorizedUser);
        vm.expectRevert("Not authorized to view this request");
        vehicleRegistry.fetchVehicleRegistrationRequest(requestId);
    }

    function test_OnlyAuditorCanApprove() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        // Non-auditor should not be able to approve
        vm.prank(dealer);
        vm.expectRevert(); // Should revert due to missing AUDITOR_ROLE
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash123");

        // Non-auditor owner should not be able to approve
        vm.prank(owner);
        vm.expectRevert();
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash123");

        // Only auditor should be able to approve
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash123"); // Should succeed
    }

    function test_OnlyAuditorCanDeny() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        // Non-auditor should not be able to deny
        vm.prank(dealer);
        vm.expectRevert(); // Should revert due to missing AUDITOR_ROLE
        vehicleRegistry.denyVehicleRegistration(requestId, "Test denial");

        // Only auditor should be able to deny
        vm.prank(auditor);
        vehicleRegistry.denyVehicleRegistration(requestId, "Test denial"); // Should succeed
    }

    function test_CannotProcessSameRequestTwice() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        // First approval should work
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash123");

        // Second approval should fail
        vm.prank(auditor);
        vm.expectRevert("Already processed");
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash456");

        // Denial after approval should also fail
        vm.prank(auditor);
        vm.expectRevert("Already processed");
        vehicleRegistry.denyVehicleRegistration(requestId, "Test reason");
    }

    function test_RoleHierarchySetup() public {
        // Check that role admins are set correctly for the new hierarchy
        assertEq(vehicleRegistry.getRoleAdmin(DEALER_ROLE), ROLE_MANAGER_ROLE);
        assertEq(vehicleRegistry.getRoleAdmin(AUDITOR_ROLE), ROLE_MANAGER_ROLE);
        assertEq(vehicleRegistry.getRoleAdmin(OWNER_ROLE), ROLE_MANAGER_ROLE);
        
        // Check that admin retains control over ROLE_MANAGER_ROLE
        assertEq(vehicleRegistry.getRoleAdmin(ROLE_MANAGER_ROLE), vehicleRegistry.DEFAULT_ADMIN_ROLE());
    }

    function test_SupportsInterface() public {
        // Test ERC721 interface
        assertTrue(vehicleRegistry.supportsInterface(0x80ac58cd)); // ERC721
        
        // Test AccessControl interface  
        assertTrue(vehicleRegistry.supportsInterface(0x7965db0b)); // AccessControl
        
        // Test ERC165 interface
        assertTrue(vehicleRegistry.supportsInterface(0x01ffc9a7)); // ERC165
    }

    function test_MultipleRegistrations() public {
        address owner2 = address(0x7);
        
        // First registration
        vm.prank(dealer);
        uint256 requestId1 = vehicleRegistry.requestVehicleRegistration("QmHash1", owner);
        
        // Second registration  
        vm.prank(dealer);
        uint256 requestId2 = vehicleRegistry.requestVehicleRegistration("QmHash2", owner2);
        
        // Approve both
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId1, "QmCert1");
        
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId2, "QmCert2");
        
        // Check both owners have their tokens
        assertEq(vehicleRegistry.ownerOf(0), owner);
        assertEq(vehicleRegistry.ownerOf(1), owner2);
        assertEq(vehicleRegistry.balanceOf(owner), 1);
        assertEq(vehicleRegistry.balanceOf(owner2), 1);
        
        // Check certificates are different
        vm.prank(owner);
        IVehicleRegistry.VehicleCertificate memory cert1 = vehicleRegistry.fetchVehicleCertificate(0);
        
        vm.prank(owner2);
        IVehicleRegistry.VehicleCertificate memory cert2 = vehicleRegistry.fetchVehicleCertificate(1);
        
        assertEq(cert1.certIpfsHash, "QmCert1");
        assertEq(cert2.certIpfsHash, "QmCert2");
    }
}