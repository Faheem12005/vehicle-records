// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {VehicleRegistry} from "./VehicleRegistry.sol";
import {IVehicleRegistry, VehicleStatus} from "./interfaces/IVehicleRegistry.sol";
import {Test} from "forge-std/Test.sol";

contract VehicleRegistryTest is Test {
    VehicleRegistry vehicleRegistry;

    address dealer = address(0x3);
    address owner = address(0x4);
    address auditor = address(0x5);

    function setUp() public {
        // Deploy contract with test contract as admin
        vehicleRegistry = new VehicleRegistry();

        vehicleRegistry.grantRole(vehicleRegistry.DEALER_ROLE(), dealer);
        vehicleRegistry.grantRole(vehicleRegistry.OWNER_ROLE(), owner);
        vehicleRegistry.grantRole(vehicleRegistry.AUDITOR_ROLE(), auditor);
    }

    function test_RequestRegistration() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123", // IPFS hash
            owner
        );

        IVehicleRegistry.VehicleRegistration memory registration = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);

        assertEq(registration.ownerAddress, owner);
        assertEq(registration.requesterAddress, dealer);
        assertEq(uint256(registration.status), uint256(VehicleStatus.Pending));
        assertTrue(!registration.minted);
    }

    function test_ApproveRegistration() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        // Auditor approves with certificate IPFS hash
        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash123");

        IVehicleRegistry.VehicleRegistration memory registration = vehicleRegistry.fetchVehicleRegistrationRequest(requestId);

        assertEq(uint256(registration.status), uint256(VehicleStatus.Approved));
        assertTrue(registration.minted);
        assertEq(registration.registrationDate, block.timestamp);
        assertEq(registration.issuerAddress, auditor);

        IVehicleRegistry.VehicleCertificate memory certificate = vehicleRegistry.fetchVehicleCertificate(0); // first token
        assertEq(certificate.ownerAddress, registration.ownerAddress);
        assertEq(certificate.issuerAddress, registration.issuerAddress);
        assertEq(certificate.certIpfsHash, "QmCertHash123");
    }

    function test_FetchCertificate_Unauthorized() public {
        vm.prank(dealer);
        uint256 requestId = vehicleRegistry.requestVehicleRegistration(
            "QmRegHash123",
            owner
        );

        vm.prank(auditor);
        vehicleRegistry.approveVehicleRegistration(requestId, "QmCertHash123");

        vm.prank(dealer);
        vm.expectRevert();
        vehicleRegistry.fetchVehicleCertificate(1); // first token
    }
}
