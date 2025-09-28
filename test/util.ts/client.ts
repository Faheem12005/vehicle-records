import { createWalletClient, createPublicClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'
import dotenv from "dotenv";

dotenv.config();

const localhost = {
    id: 31_337,
    name: 'Localhost',
    nativeCurrency: {
        decimals: 18,
        name: 'Ether',
        symbol: 'ETH',
    },
    rpcUrls: {
        default: { http: ['http://127.0.0.1:8545'] },
    },
}
export const walletClient = createWalletClient({
    account: privateKeyToAccount(process.env.ADMIN_PRIVATE_KEY as `0x${string}`),
    chain: localhost,
    transport: http("http://127.0.0.1:8545"),
})

export const publicClient = createPublicClient({
    chain: localhost,
    transport: http("http://127.0.0.1:8545"),
})