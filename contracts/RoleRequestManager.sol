// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IVehicleRegistryRoles {
    function grantRole(bytes32 role, address account) external;
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

    event RoleRequested(uint256 indexed requestId, address indexed requester, bytes32 role);
    event RoleApproved(uint256 indexed requestId, address indexed requester, bytes32 role);
    event RoleDenied(uint256 indexed requestId, address indexed requester, bytes32 role);

    constructor(address registryAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        registry = IVehicleRegistryRoles(registryAddress);
    }

    // Users request a role
    function requestRole(bytes32 role) external returns (uint256) {
        require(role != DEFAULT_ADMIN_ROLE, "Cannot request admin role");

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

        registry.grantRole(request.role, request.requester);
        request.approved = true;

        emit RoleApproved(requestId, request.requester, request.role);
    }

    // Admin denies role request
    function denyRoleRequest(uint256 requestId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        RoleRequest storage request = pendingRequests[requestId];
        require(request.requester != address(0), "No such request");
        require(!request.approved, "Already processed");

        emit RoleDenied(requestId, request.requester, request.role);
        delete pendingRequests[requestId]; // optional cleanup
    }
}
