import { ethers, parseUnits } from "ethers";
import { FlashbotsBundleProvider, FlashbotsBundleResolution } from '@flashbots/ethers-provider-bundle';

const WSS_URL = process.env.WSS_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (!WSS_URL) {
    throw new Error('WSS_URL environment variable is not set');
}

if (!PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY environment variable is not set');
}

// Create WebSocket provider
const provider = new ethers.WebSocketProvider(WSS_URL);

const init = async () => {
    try {
        const network = await provider.getNetwork();
        console.log(`Network: ${network.name}`);
        console.log(`ChainId: ${network.chainId}`);
        await main();
    } catch (error) {
        console.error("Initialization error:", error);
        setTimeout(init, 3000);
    }
};

// Create wallet for sending frontrun transactions
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
const FLASHBOTS_ENDPOINT = 'https://relay-sepolia.flashbots.net'; // For testnet
// const FLASHBOTS_ENDPOINT = 'https://relay.flashbots.net'; // For mainnet
const flashbotsProvider = await FlashbotsBundleProvider.create(
    provider,
    wallet,
    FLASHBOTS_ENDPOINT,
    'sepolia'
);

const NFTMarketplaceOnSepolia = '0x891584924f491029f6e17AD0e9555Bc5E3053AaB';

const main = async () => {
    // Monitor pending mint transactions
    console.log("\nMonitoring pending transactions...");
    provider.on("pending", async (txHash) => {
        if (txHash) {

            // Get transaction details
            let tx = await provider.getTransaction(txHash);
            if (tx && tx.to && ethers.getAddress(tx.to) === ethers.getAddress(NFTMarketplaceOnSepolia)) { 
                console.log("Target contract tx detected, raw transaction info:");
                console.log(tx);
                if (tx.data.indexOf('0xa8eac492') !== -1 ) {
                    await sendMyBundle(tx).catch(console.error);
                    process.exit(0);
                }
            }
        }
    });
};

async function sendMyBundle(tx1) {
    console.log(tx1);
    let myTransaction;
    try {
        const blockNumber = await provider.getBlockNumber();
        const targetBlockNumber = blockNumber + 1;
        const chainId = (await provider.getNetwork()).chainId;

        // Get current network fee data
        const feeData = await provider.getFeeData();
        console.log("Current network fee data:", feeData);

        // Get current network gas data
        const block = await provider.getBlock(blockNumber);
        const currentBaseFee = BigInt(block.baseFeePerGas);
        console.log("Current network baseFee:", currentBaseFee.toString());
        // Handle maxFeePerGas and maxPriorityFeePerGas
        const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas * 12n / 10n;
        const maxBaseFeeInFutureBlock = FlashbotsBundleProvider.getMaxBaseFeeInFutureBlock(block.baseFeePerGas, 1);
        const maxFeePerGas = maxBaseFeeInFutureBlock + maxPriorityFeePerGas * 11n / 10n;
        // Prepare our own transaction, ensuring all values are BigInt
        myTransaction = {
            to: NFTMarketplaceOnSepolia,
            data: "0xe6ab14340000000000000000000000000000000000000000000000000000000000000001",
            value: parseUnits("0.01", "ether"),
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: (80000n * 11n / 10n),
            chainId: chainId,
            type: 2,
            nonce: await wallet.getNonce()
        };

        console.log("Transaction fee information:", {
            maxFeePerGas: maxFeePerGas.toString(),
            maxPriorityFeePerGas: maxPriorityFeePerGas.toString(),
            maxBaseFeeInFutureBlock: maxBaseFeeInFutureBlock.toString()
        });

        // Get serialized data of pending transaction
        const pendingTx = ethers.Transaction.from(tx1);
        const pendingTxSerialized = pendingTx.serialized;

        console.log('myTx:', myTransaction);
        const signedTransactionsBundle = await flashbotsProvider.signBundle(
            [
                { signedTransaction: pendingTxSerialized },
                { signer: wallet, transaction: myTransaction }
            ]
        );
        const signedMyTransaction = await flashbotsProvider.signBundle(
            [
                { signer: wallet, transaction: myTransaction }
            ]
        );

        let signedTransactions = signedTransactionsBundle; 

        // Try to send transaction for 100 blocks due to limited Flashbots nodes on testnet
        for (let i = 1; i <= 100; i++) {
            let targetBlockNumberNew = await provider.getBlockNumber() + 1;
            console.log(`---> Trial:[${i}] Sending transaction to block: ${targetBlockNumberNew}`);
           const bundleSimulationResult = await flashbotsProvider.simulate(signedTransactions, targetBlockNumberNew);
            console.log('Simulation result:', bundleSimulationResult);
            if ("error" in bundleSimulationResult) {
                console.error("Simulation failed:", bundleSimulationResult.error.message);
                break;
            }
            console.log("Simulation succeeded, preparing to send bundle...");
            const res = await flashbotsProvider.sendRawBundle(
                signedTransactions,
                targetBlockNumberNew
            );

            if ("error" in res) {
                throw new Error(res.error.message);
            }

            // Check if transaction is included in the block
            const bundleResolution = await res.wait();
            if (bundleResolution === FlashbotsBundleResolution.BundleIncluded) {
                console.log(`<--- Congrats:[${i}], Transaction included in block: ${targetBlockNumberNew}`);
                console.log("Transaction details:", res);
                flashbotsProvider.getBundleStatsV2(res.bundleHash).then((stats) => {
                    console.log("Bundle stats:", stats);
                });
                process.exit(0);
            } else {
                console.log(`<--- Failure @trial #[${i}]! ${
                bundleResolution === FlashbotsBundleResolution.BlockPassedWithoutInclusion 
                  ? `Transaction not included in block: ${targetBlockNumberNew}` 
                  : bundleResolution === FlashbotsBundleResolution.AccountNonceTooHigh
                  ? "Nonce too high, please reset"
                  : ""
                }`);
            }
            signedTransactions = signedMyTransaction;
        }
    } catch (error) {
        console.error('Bundle sending failed:', error);
        if (error.message.includes('serialized')) {
            console.error('Transaction serialization failed, transaction data:', tx1);
        }
        console.error('Transaction parameters:', {
            maxFeePerGas: myTransaction?.maxFeePerGas?.toString(),
            gasLimit: myTransaction?.gasLimit?.toString(),
            value: myTransaction?.value?.toString()
        });        
        console.error('Error details:', error.message);
    }
}

init();