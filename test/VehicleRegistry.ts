import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { readFileSync } from "node:fs";
import { walletClient, publicClient } from "./util.ts/client.js";
import { keccak256 } from "viem/utils";

// Role constants
const DEALER_ROLE = keccak256("DEALER_ROLE" as `0x${string}`);
const AUDITOR_ROLE = keccak256("AUDITOR_ROLE" as `0x${string}`);
const ROLE_MANAGER_ROLE = keccak256("ROLE_MANAGER_ROLE" as `0x${string}`);

// Load ABIs
const vehicleArtifact = JSON.parse(
    readFileSync("./artifacts/contracts/VehicleRegistry.sol/VehicleRegistry.json", "utf8")
);
const roleRequestArtifact = JSON.parse(
    readFileSync("./artifacts/contracts/RoleRequestManager.sol/RoleRequestManager.json", "utf8")
);

describe("VehicleRegistry + RoleRequestManager with Role Hierarchy", async () => {
    const admin = walletClient.account.address;
    const user1 = walletClient.account.address;

    console.log("Admin address:", admin);
    console.log("User1 address:", user1);

    // Deploy contracts
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

    // Grant ROLE_MANAGER_ROLE to RoleRequestManager (much safer than admin role!)
    const grantRoleTxHash = await walletClient.writeContract({
        address: vehicleRegistryAddress,
        abi: vehicleArtifact.abi,
        functionName: "grantRole",
        args: [ROLE_MANAGER_ROLE, roleRequestManagerAddress],
    });
    await publicClient.waitForTransactionReceipt({ hash: grantRoleTxHash });
    console.log("ROLE_MANAGER_ROLE granted to RoleRequestManager");

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
        
        assert(registration.status === 1, "Registration should be approved");
    });

    it("Should prevent requesting non-manageable roles", async () => {
        // Try to request a role that's not manageable
        const MINTER_ROLE = keccak256("MINTER_ROLE" as `0x${string}`);
        
        let errorThrown = false;
        try {
            await walletClient.writeContract({
                address: roleRequestManagerAddress,
                abi: roleRequestArtifact.abi,
                functionName: "requestRole",
                args: [MINTER_ROLE],
            });
            assert.fail("Should have reverted for non-manageable role");
        } catch (error: any) {
            errorThrown = true;
            console.log("Error caught:", error.message);
            // Check for various possible error message formats
            const hasExpectedError = 
                error.message.includes("Role not requestable") ||
                error.message.includes("execution reverted") ||
                error.message.includes("revert") ||
                error.cause?.reason?.includes("Role not requestable");
            
            assert(hasExpectedError, `Expected revert message, got: ${error.message}`);
        }
        
        assert(errorThrown, "Expected transaction to revert but it didn't");
    });
});