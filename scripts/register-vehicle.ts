import { createWalletClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";
import dotenv from "dotenv";

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

// Dealer wallet client
const dealerWalletClient = createWalletClient({
  account: dealerAccount,
  chain: localChain,
  transport: http("http://127.0.0.1:8545"),
});

const contractAddress = process.env.CONTRACT_ADDRESS!;

async function main() {

  // Request vehicle registration
  const requestId = await dealerWalletClient.writeContract({
    address: contractAddress,
    abi,
    functionName: "requestVehicleRegistration",
    args: [
      "ipfsHash1234", // Example IPFS hash
      userAccount.address,
    ],
  });

  console.log("Vehicle registration requested. Request ID:", requestId);
}

main().catch(console.error);
