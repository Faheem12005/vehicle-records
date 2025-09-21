// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {VehicleRegistry} from "./VehicleRegistry.sol";
import {Test} from "forge-std/Test.sol";

contract VehicleRegistryTest is Test {
    VehicleRegistry vehicleRegistry;

    address minter = address(0x2);
    address dealer = address(0x3);
    address owner = address(0x4);
    address auditor = address(0x5);

    function setUp() public {
        // Deploy contract with test contract as admin
        vehicleRegistry = new VehicleRegistry();

        // Now the test contract itself is admin, can grant roles directly
        vehicleRegistry.grantRole(vehicleRegistry.DEALER_ROLE(), dealer);
        vehicleRegistry.grantRole(vehicleRegistry.OWNER_ROLE(), owner);
        vehicleRegistry.grantRole(vehicleRegistry.AUDITOR_ROLE(), auditor);
    }

    function test_RequestRegistration() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "1HGCM82633A123456",
            "Honda",
            "Accord",
            2020,
            owner,
            "CHS123456789",
            "ENG123456789"
        );

        VehicleRegistry.VehicleRegistration memory registration = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);

        assertEq(registration.vin, "1HGCM82633A123456"); 
        assertTrue(!registration.approved);
        assertTrue(!registration.minted);
    }

    function test_ApproveRegistration() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "1HGCM82633A123456",
            "Honda",
            "Accord",
            2020,
            owner,
            "CHS123456789",
            "ENG123456789"
        );

        // Auditor approves
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId);

        VehicleRegistry.VehicleRegistration memory registration = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);

        assertTrue(registration.approved);
        assertTrue(registration.minted);
        assertEq(registration.registrationDate, block.timestamp);
        assertEq(registration.issuerAddress, auditor);

        VehicleRegistry.VehicleCertificate memory certificate = vehicleRegistry.fetchVehicleCertificate(0); // first token
        assertEq(certificate.vin, registration.vin);
        assertEq(certificate.ownerAddress, registration.ownerAddress);
        assertEq(certificate.issuerAddress, registration.issuerAddress);

    }

    function test_FetchCertificate_Unauthorized() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "1HGCM82633A123456",
            "Honda",
            "Accord",
            2020,
            owner,
            "CHS123456789",
            "ENG123456789"
        );

        // Auditor approves
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId);

        // Another address tries to fetch the certificate
        vm.prank(dealer);
        vm.expectRevert();
        vehicleRegistry.fetchVehicleCertificate(1); // second token
    }
}
