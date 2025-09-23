// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
enum VehicleStatus { Pending, Approved, Rejected }

interface IVehicleRegistry {
    // -------- Structs --------
    struct VehicleCertificate {
        address ownerAddress;
        uint256 registrationDate;
        address issuerAddress;
        string certIpfsHash;
    }

    struct VehicleRegistration {
        address ownerAddress;
        address requesterAddress;
        uint256 registrationDate;
        address issuerAddress;
        VehicleStatus status;
        string regIpfsHash;
        bool minted;
    }

    // -------- Core Functions --------
    function requestVehicleRegistration(
        string memory certipfsHash,
        address ownerAddress

    ) external returns (uint256);

    function approveVehicleRegistration(
        uint256 requestId, 
        string memory certIpfsHash
    ) external;

    function fetchVehicleCertificate(
        uint256 tokenId
    ) external view returns (VehicleCertificate memory);

    function fetchVehicleRegistrationRequest(
        uint256 requestId
    ) external view returns (VehicleRegistration memory);
}
