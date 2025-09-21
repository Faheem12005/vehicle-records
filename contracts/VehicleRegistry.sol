// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract VehicleRegistry is ERC721, AccessControl {
    struct VehicleCertificate {
        string vin; // Vehicle Identification Number
        string make;
        string model;
        uint16 manufactureYear;
        address ownerAddress;
        uint256 registrationDate;
        address issuerAddress;
        string chasisNumber;
        string engineNumber;
    }

    mapping(uint256 => VehicleCertificate) public vehicleCertificates;

    struct VehicleRegistration {
        string vin; // Vehicle Identification Number
        string make;
        string model;
        uint16 manufactureYear;
        address ownerAddress;
        address requesterAddress;
        uint256 registrationDate;
        address issuerAddress;
        string chasisNumber;
        string engineNumber;
        bool approved;
        bool minted;
    }

    uint256 private _nextRequestId;
    mapping(uint256 => VehicleRegistration) public vehicleRegistrations;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant DEALER_ROLE = keccak256("DEALER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    uint256 private _nextTokenId;

    constructor() ERC721("VehicleRegistry", "VRE") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(TRANSFER_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
        _grantRole(DEALER_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
    }

    function requestVehicleRegistration(
        string memory vin,
        string memory make,
        string memory model,
        uint16 manufactureYear,
        address ownerAddress,
        string memory chasisNumber,
        string memory engineNumber
    ) public returns (uint256) {
        require(
            hasRole(DEALER_ROLE, msg.sender) || hasRole(OWNER_ROLE, msg.sender),
            "Not authorized to request registration"
        );
        uint256 requestId = _nextRequestId++;
        vehicleRegistrations[requestId] = VehicleRegistration({
            vin: vin,
            make: make,
            model: model,
            manufactureYear: manufactureYear,
            ownerAddress: ownerAddress,
            requesterAddress: msg.sender,
            registrationDate: 0,
            issuerAddress: address(0),
            chasisNumber: chasisNumber,
            engineNumber: engineNumber,
            approved: false,
            minted: false
        });
        return requestId;
    }

    function approveVehicleRegistration(
        uint256 requestId
    ) public onlyRole(AUDITOR_ROLE) {
        VehicleRegistration storage registration = vehicleRegistrations[
            requestId
        ];
        require(!registration.approved, "Already approved");
        registration.approved = true;

        // Mint the NFT
        uint256 tokenId = _nextTokenId++;
        _safeMint(registration.ownerAddress, tokenId);
        registration.minted = true;
        registration.registrationDate = block.timestamp;
        registration.issuerAddress = msg.sender;
        vehicleCertificates[tokenId] = VehicleCertificate({
            vin: registration.vin,
            make: registration.make,
            model: registration.model,
            manufactureYear: registration.manufactureYear,
            ownerAddress: registration.ownerAddress,
            registrationDate: registration.registrationDate,
            issuerAddress: registration.issuerAddress,
            chasisNumber: registration.chasisNumber,
            engineNumber: registration.engineNumber
        });
    }

    function fetchVehicleCertificate(
        uint256 tokenId
    ) public view returns (VehicleCertificate memory) {
        _requireOwned(tokenId);
        return vehicleCertificates[tokenId];
    }

    function fetchVehicleRegistrationRequest(
        uint256 requestId
    ) public view returns (VehicleRegistration memory) {
        VehicleRegistration memory registration = vehicleRegistrations[
            requestId
        ];
        require(
            hasRole(AUDITOR_ROLE, msg.sender) ||
                msg.sender == registration.requesterAddress ||
                msg.sender == registration.ownerAddress,
            "Not authorized to view this request"
        );
        return registration;
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
