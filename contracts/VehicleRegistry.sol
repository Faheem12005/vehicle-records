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

    mapping(uint256 => VehicleRegistration) public vehicleRegistrations;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    uint256 private _nextTokenId;

    constructor(
        address defaultAdmin,
        address minter
    ) ERC721("VehicleRegistry", "VRE") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(BURNER_ROLE, defaultAdmin);
        _grantRole(TRANSFER_ROLE, defaultAdmin);
        _grantRole(UPDATER_ROLE, defaultAdmin);
        _grantRole(AUDITOR_ROLE, defaultAdmin);
    }

    function safeMint(
        address to
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
