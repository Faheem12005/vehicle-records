import { createPublicClient, createWalletClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";
import dotenv from "dotenv";
import { grantRolesIfMissing } from "./grantRoleUtil.js";

dotenv.config();

// Load ABI
const artifact = JSON.parse(readFileSync("./artifacts/contracts/VehicleRegistry.sol/VehicleRegistry.json", "utf8"));
const abi = artifact.abi;

// Localchain
const localChain = {
  id: 31337,
  name: 'Localhost',
  nativeCurrency: { decimals: 18, name: 'Ether', symbol: 'ETH' },
  rpcUrls: { default: { http: ['http://127.0.0.1:8545'] } },
};

// Accounts
const dealerAccount = privateKeyToAccount(process.env.DEALER_PRIVATE_KEY!);
const userAccount = privateKeyToAccount(process.env.USER_PRIVATE_KEY!);

// Add public client for reading transaction receipts
const publicClient = createPublicClient({
  chain: localChain,
  transport: http("http://127.0.0.1:8545"),
});

// Dealer wallet client
const dealerWalletClient = createWalletClient({
  account: dealerAccount,
  chain: localChain,
  transport: http("http://127.0.0.1:8545"),
});

const contractAddress = process.env.CONTRACT_ADDRESS!;

async function main() {
  // Ensure roles exist first (this already works)
  await grantRolesIfMissing({
    ownerAddress: userAccount.address,
    auditAddress: privateKeyToAccount(process.env.AUDIT_PRIVATE_KEY!).address,
    dealerAddress: dealerAccount.address,
  });

  // Request vehicle registration - get transaction hash
  const hash = await dealerWalletClient.writeContract({
    address: contractAddress,
    abi,
    functionName: "requestVehicleRegistration",
    args: [
      "ipfsHash1234", // Example IPFS hash
      userAccount.address,
    ],
  });

  console.log("Vehicle registration submitted. Hash:", hash);

  // Wait for transaction to be confirmed before script exits
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log("Vehicle registration confirmed in block:", receipt.blockNumber);
}

main().catch(console.error);