import { createPublicClient, createWalletClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";
import dotenv from "dotenv";

dotenv.config();

// Load ABI
const artifact = JSON.parse(readFileSync("./artifacts/contracts/VehicleRegistry.sol/VehicleRegistry.json", "utf8"));
const abi = artifact.abi;

// Local testnet
const localChain = {
  id: 31337,
  name: 'Localhost',
  nativeCurrency: { decimals: 18, name: 'Ether', symbol: 'ETH' },
  rpcUrls: { default: { http: ['http://127.0.0.1:8545'] } },
};

// Accounts
const adminAccount = privateKeyToAccount(process.env.ADMIN_PRIVATE_KEY!);

// Clients
const publicClient = createPublicClient({
  chain: localChain,
  transport: http('http://127.0.0.1:8545'),
});

const adminWalletClient = createWalletClient({
  account: adminAccount,
  chain: localChain,
  transport: http('http://127.0.0.1:8545'),
});

const contractAddress = process.env.CONTRACT_ADDRESS!;

/**
 * Grants OWNER, AUDITOR, DEALER roles if the accounts don't already have them.
 */
export async function grantRolesIfMissing({
  ownerAddress,
  auditAddress,
  dealerAddress,
}: {
  ownerAddress: string;
  auditAddress: string;
  dealerAddress: string;
}) {
  const roles = await Promise.all([
    publicClient.readContract({ address: contractAddress, abi, functionName: 'OWNER_ROLE' }),
    publicClient.readContract({ address: contractAddress, abi, functionName: 'AUDITOR_ROLE' }),
    publicClient.readContract({ address: contractAddress, abi, functionName: 'DEALER_ROLE' }),
  ]);

  const [ownerRole, auditorRole, dealerRole] = roles;

  // hasRole helper
  async function hasRole(role: `0x${string}`, account: string) {
    return publicClient.readContract({
      address: contractAddress,
      abi,
      functionName: 'hasRole',
      args: [role, account],
    });
  }

  // Grant OWNER_ROLE
  if (!(await hasRole(ownerRole, ownerAddress))) {
    console.log(`Granting OWNER_ROLE to ${ownerAddress}...`);
    await adminWalletClient.writeContract({
      address: contractAddress,
      abi,
      functionName: 'grantRole',
      args: [ownerRole, ownerAddress],
    });
    console.log("OWNER_ROLE granted");
  }

  // Grant AUDITOR_ROLE
  if (!(await hasRole(auditorRole, auditAddress))) {
    console.log(`Granting AUDITOR_ROLE to ${auditAddress}...`);
    await adminWalletClient.writeContract({
      address: contractAddress,
      abi,
      functionName: 'grantRole',
      args: [auditorRole, auditAddress],
    });
    console.log("AUDITOR_ROLE granted");
  }

  // Grant DEALER_ROLE
  if (!(await hasRole(dealerRole, dealerAddress))) {
    console.log(`Granting DEALER_ROLE to ${dealerAddress}...`);
    await adminWalletClient.writeContract({
      address: contractAddress,
      abi,
      functionName: 'grantRole',
      args: [dealerRole, dealerAddress],
    });
    console.log("DEALER_ROLE granted");
  }
}
