import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { readFileSync } from "node:fs";
import { walletClient, publicClient } from "./util.ts/client.js";
import { keccak256 } from "viem/utils";

// Role constants
const DEALER_ROLE = keccak256("DEALER_ROLE" as `0x${string}`);
const AUDITOR_ROLE = keccak256("AUDITOR_ROLE" as `0x${string}`);
const DEFAULT_ADMIN_ROLE = "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`;

// Load ABIs
const vehicleArtifact = JSON.parse(
    readFileSync("./artifacts/contracts/VehicleRegistry.sol/VehicleRegistry.json", "utf8")
);
const roleRequestArtifact = JSON.parse(
    readFileSync("./artifacts/contracts/RoleRequestManager.sol/RoleRequestManager.json", "utf8")
);

describe("VehicleRegistry + RoleRequestManager", async () => {
    const admin = walletClient.account.address;
    const user1 = walletClient.account.address;

    console.log("Admin address:", admin);
    console.log("User1 address:", user1);

    // Deploy contracts once
    //@ts-ignore
    const vehicleRegistryTxHash = await walletClient.deployContract({
        account: walletClient.account,
        abi: vehicleArtifact.abi,
        bytecode: vehicleArtifact.bytecode,
    });
    const vehicleRegistryReceipt = await publicClient.waitForTransactionReceipt({ hash: vehicleRegistryTxHash });
    const vehicleRegistryAddress = vehicleRegistryReceipt.contractAddress!;
    console.log("VehicleRegistry deployed at:", vehicleRegistryAddress);

    const roleRequestManagerTxHash = await walletClient.deployContract({
        account: walletClient.account,
        abi: roleRequestArtifact.abi,
        bytecode: roleRequestArtifact.bytecode,
        args: [vehicleRegistryAddress],
    });
    const roleRequestManagerReceipt = await publicClient.waitForTransactionReceipt({ hash: roleRequestManagerTxHash });
    const roleRequestManagerAddress = roleRequestManagerReceipt.contractAddress!;
    console.log("RoleRequestManager deployed at:", roleRequestManagerAddress);

    // Grant admin role to RoleRequestManager so it can grant roles in VehicleRegistry
    const grantRoleTxHash = await walletClient.writeContract({
        address: vehicleRegistryAddress,
        abi: vehicleArtifact.abi,
        functionName: "grantRole",
        args: [DEFAULT_ADMIN_ROLE, roleRequestManagerAddress],
    });
    await publicClient.waitForTransactionReceipt({ hash: grantRoleTxHash });
    console.log("Admin role granted to RoleRequestManager");

    it("User can request a role and admin can approve it", async () => {
        // User requests a role
        const requestTxHash = await walletClient.writeContract({
            address: roleRequestManagerAddress,
            abi: roleRequestArtifact.abi,
            functionName: "requestRole",
            args: [DEALER_ROLE],
        });
        await publicClient.waitForTransactionReceipt({ hash: requestTxHash });
        console.log("Role request transaction hash:", requestTxHash);

        // Note: Request ID starts from 0, not 1
        const requestId = 0n;
        
        // Admin approves the role request
        const approveTxHash = await walletClient.writeContract({
            address: roleRequestManagerAddress,
            abi: roleRequestArtifact.abi,
            functionName: "approveRoleRequest",
            args: [requestId],
        });
        await publicClient.waitForTransactionReceipt({ hash: approveTxHash });
        console.log("Role approved for request ID:", requestId);

        // Verify user has the role in VehicleRegistry
        const hasRole = await publicClient.readContract({
            address: vehicleRegistryAddress,
            abi: vehicleArtifact.abi,
            functionName: "hasRole",
            args: [DEALER_ROLE, user1],
        });
        assert(hasRole, "User should have DEALER_ROLE after approval");
    });

    it("User can request vehicle registration and admin can approve", async () => {
        const regIpfsHash = "QmFakeHash123";
        
        // User requests vehicle registration
        const requestTxHash = await walletClient.writeContract({
            address: vehicleRegistryAddress,
            abi: vehicleArtifact.abi,
            functionName: "requestVehicleRegistration",
            args: [regIpfsHash, user1],
        });
        await publicClient.waitForTransactionReceipt({ hash: requestTxHash });
        console.log("Vehicle registration request hash:", requestTxHash);

        // Note: Vehicle registration request ID also starts from 0
        const requestId = 0n;
        const certHash = "QmCertHash456";
        
        // Admin approves the vehicle registration
        const approveTxHash = await walletClient.writeContract({
            address: vehicleRegistryAddress,
            abi: vehicleArtifact.abi,
            functionName: "approveVehicleRegistration",
            args: [requestId, certHash],
        });
        await publicClient.waitForTransactionReceipt({ hash: approveTxHash });
        console.log("Vehicle registration approved for request ID:", requestId);

        // Verify registration status
        const registration = await publicClient.readContract({
            address: vehicleRegistryAddress,
            abi: vehicleArtifact.abi,
            functionName: "fetchVehicleRegistrationRequest",
            args: [requestId],
        });
        
        // Assuming status 1 means approved (check your contract enum)
        assert(registration.status === 1, "Registration should be approved");
    });
});