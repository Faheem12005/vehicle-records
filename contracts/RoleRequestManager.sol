// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IVehicleRegistryRoles {
    function grantManagedRole(bytes32 role, address account) external;
    function revokeManagedRole(bytes32 role, address account) external;
}

contract RoleRequestManager is AccessControl {
    struct RoleRequest {
        address requester;
        bytes32 role;
        bool approved;
    }

    mapping(uint256 => RoleRequest) public pendingRequests;
    uint256 private _nextRoleRequestId;
    IVehicleRegistryRoles public registry;

    // Define which roles can be requested
    bytes32 public constant DEALER_ROLE = keccak256("DEALER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    event RoleRequested(uint256 indexed requestId, address indexed requester, bytes32 role);
    event RoleApproved(uint256 indexed requestId, address indexed requester, bytes32 role);
    event RoleDenied(uint256 indexed requestId, address indexed requester, bytes32 role);

    constructor(address registryAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        registry = IVehicleRegistryRoles(registryAddress);
    }

    // Users can only request specific manageable roles
    function requestRole(bytes32 role) external returns (uint256) {
        require(
            role == DEALER_ROLE || 
            role == AUDITOR_ROLE || 
            role == OWNER_ROLE, 
            "Role not requestable"
        );
        
        uint256 requestId = _nextRoleRequestId++;
        pendingRequests[requestId] = RoleRequest({
            requester: msg.sender,
            role: role,
            approved: false
        });
        emit RoleRequested(requestId, msg.sender, role);
        return requestId;
    }

    // Admin approves role request
    function approveRoleRequest(uint256 requestId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RoleRequest storage request = pendingRequests[requestId];
        require(request.requester != address(0), "No such request");
        require(!request.approved, "Already processed");

        // Use the specific function for managed roles
        registry.grantManagedRole(request.role, request.requester);
        request.approved = true;
        emit RoleApproved(requestId, request.requester, request.role);
    }

    // Admin denies role request
    function denyRoleRequest(uint256 requestId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RoleRequest storage request = pendingRequests[requestId];
        require(request.requester != address(0), "No such request");
        require(!request.approved, "Already processed");

        emit RoleDenied(requestId, request.requester, request.role);
        delete pendingRequests[requestId];
    }

    // Admin can revoke roles if needed
    function revokeUserRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            role == DEALER_ROLE || 
            role == AUDITOR_ROLE || 
            role == OWNER_ROLE, 
            "Role not manageable"
        );
        registry.revokeManagedRole(role, account);
    }
}   