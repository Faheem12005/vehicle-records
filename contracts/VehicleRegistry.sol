// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/IVehicleRegistry.sol";

contract VehicleRegistry is ERC721, AccessControl, IVehicleRegistry {
    mapping(uint256 => VehicleCertificate) public vehicleCertificates;
    mapping(uint256 => VehicleRegistration) public vehicleRegistrations;

    uint256 private _nextRequestId;
    uint256 private _nextTokenId;

    // Role constants
    bytes32 public constant ROLE_MANAGER_ROLE = keccak256("ROLE_MANAGER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant DEALER_ROLE = keccak256("DEALER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    constructor() ERC721("VehicleRegistry", "VRE") {
        // Grant admin role to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Set up role hierarchy - ROLE_MANAGER_ROLE can manage these specific roles
        _setRoleAdmin(DEALER_ROLE, ROLE_MANAGER_ROLE);
        _setRoleAdmin(AUDITOR_ROLE, ROLE_MANAGER_ROLE);
        _setRoleAdmin(OWNER_ROLE, ROLE_MANAGER_ROLE);
        
        // Keep admin control over critical roles
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(TRANSFER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(UPDATER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(ROLE_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        
        // Grant initial roles to deployer
        _grantRole(ROLE_MANAGER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(TRANSFER_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
        _grantRole(DEALER_ROLE, msg.sender);
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
    }

    // Function to allow ROLE_MANAGER to grant managed roles
    function grantManagedRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        require(
            role == DEALER_ROLE || 
            role == AUDITOR_ROLE || 
            role == OWNER_ROLE, 
            "Role not manageable by ROLE_MANAGER"
        );
        _grantRole(role, account);
    }

    // Function to allow ROLE_MANAGER to revoke managed roles
    function revokeManagedRole(bytes32 role, address account) external onlyRole(getRoleAdmin(role)) {
        require(
            role == DEALER_ROLE || 
            role == AUDITOR_ROLE || 
            role == OWNER_ROLE, 
            "Role not manageable by ROLE_MANAGER"
        );
        _revokeRole(role, account);
    }

    //events
    event VehicleRegistrationRequested(
        uint256 indexed requestId,
        address indexed requester,
        address indexed owner,
        string regIpfsHash
    );

    event VehicleRegistrationApproved(
        uint256 indexed requestId,
        uint256 indexed tokenId,
        address indexed owner,
        string certIpfsHash
    );

    event VehicleRegistrationDenied(
        uint256 indexed requestId,
        address indexed auditor,
        address indexed owner,
        string reason
    );

    // -------- Implementing IVehicleRegistry --------
    function requestVehicleRegistration(
        string memory regIpfsHash,
        address ownerAddress
    ) external override returns (uint256) {
        uint256 requestId = _nextRequestId++;
        vehicleRegistrations[requestId] = VehicleRegistration({
            ownerAddress: ownerAddress,
            requesterAddress: msg.sender,
            registrationDate: 0,
            issuerAddress: address(0),
            status: VehicleStatus.Pending,
            regIpfsHash: regIpfsHash,
            minted: false
        });
        emit VehicleRegistrationRequested(
            requestId,
            msg.sender,
            ownerAddress,
            regIpfsHash
        );
        return requestId;
    }

    function approveVehicleRegistration(
        uint256 requestId,
        string memory certIpfsHash
    ) public override onlyRole(AUDITOR_ROLE) {
        VehicleRegistration storage registration = vehicleRegistrations[
            requestId
        ];
        require(
            registration.status == VehicleStatus.Pending,
            "Already processed"
        );

        registration.status = VehicleStatus.Approved;
        registration.registrationDate = block.timestamp;
        registration.issuerAddress = msg.sender;

        uint256 tokenId = _nextTokenId++;
        _safeMint(registration.ownerAddress, tokenId);
        registration.minted = true;
        vehicleCertificates[tokenId] = VehicleCertificate({
            ownerAddress: registration.ownerAddress,
            registrationDate: registration.registrationDate,
            issuerAddress: registration.issuerAddress,
            certIpfsHash: certIpfsHash
        });
        emit VehicleRegistrationApproved(
            requestId,
            tokenId,
            registration.ownerAddress,
            certIpfsHash
        );
    }

    function denyVehicleRegistration(
        uint256 requestId,
        string memory reason
    ) public override onlyRole(AUDITOR_ROLE) {
        VehicleRegistration storage registration = vehicleRegistrations[
            requestId
        ];
        require(
            registration.status == VehicleStatus.Pending,
            "Already processed"
        );

        registration.status = VehicleStatus.Rejected;
        registration.registrationDate = block.timestamp;
        registration.issuerAddress = msg.sender;
        registration.minted = false;

        emit VehicleRegistrationDenied(
            requestId,
            msg.sender,
            registration.ownerAddress,
            reason
        );
    }

    function fetchVehicleCertificate(
        uint256 tokenId
    ) public view override returns (VehicleCertificate memory) {
        _requireOwned(tokenId);
        return vehicleCertificates[tokenId];
    }

    function fetchVehicleRegistrationRequest(
        uint256 requestId
    ) public view override returns (VehicleRegistration memory) {
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

    // required overrides
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}