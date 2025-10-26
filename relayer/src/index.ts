import { ethers } from "ethers";
import dotenv from "dotenv";
import winston from "winston";
import { NFTLockedEvent, BatchLockedEvent } from "./types/events.js";

// Load environment variables
dotenv.config();

// Configure logger
const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.colorize(),
    winston.format.simple()
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: "relayer.log" }),
  ],
});

// Configuration
const SOURCE_RPC = process.env.SOURCE_RPC || "http://localhost:8545";
const DEST_RPC = process.env.DEST_RPC || "http://localhost:8546";
const PRIVATE_KEY =
  process.env.PRIVATE_KEY ||
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const SOURCE_BRIDGE = process.env.SOURCE_BRIDGE || "";
const DEST_BRIDGE = process.env.DEST_BRIDGE || "";
const POLL_INTERVAL = parseInt(process.env.POLL_INTERVAL || "5000");

// Contract ABIs
const SOURCE_BRIDGE_ABI = [
  "event NFTLocked(bytes32 indexed bridgeId, address indexed nftContract, uint256 indexed tokenId, address owner, uint256 destinationChainId, uint256 timestamp)",
  "event BatchLocked(bytes32[] bridgeIds, bytes32 merkleRoot, uint256 count)",
];

const DEST_BRIDGE_ABI = [
  "function mintWrappedNFT(address recipient, address originalContract, uint256 originalTokenId, bytes32 bridgeId, bytes calldata zkProof) external returns (uint256)",
  "function batchMintWrappedNFTs(address[] recipients, address[] originalContracts, uint256[] originalTokenIds, bytes32[] bridgeIds, bytes32 merkleRoot, bytes calldata zkProof) external returns (uint256[])",
  "function isMinted(bytes32 bridgeId) view returns (bool)",
];

// Mock ZK proof (128 bytes)
const MOCK_ZK_PROOF = "0x" + "0".repeat(256);

class RelayerService {
  private sourceProvider: ethers.JsonRpcProvider;
  private destProvider: ethers.JsonRpcProvider;
  private sourceWallet: ethers.Wallet;
  private destWallet: ethers.Wallet;
  private sourceBridge: ethers.Contract;
  private destBridge: ethers.Contract;
  private isRunning: boolean = false;

  constructor() {
    // Initialize providers
    this.sourceProvider = new ethers.JsonRpcProvider(SOURCE_RPC);
    this.destProvider = new ethers.JsonRpcProvider(DEST_RPC);

    // Override resolveName to prevent ENS resolution
    const originalResolveName = this.sourceProvider.resolveName.bind(
      this.sourceProvider
    );
    this.sourceProvider.resolveName = async (name: string) => {
      // If it's an address, return as-is, otherwise return null to prevent ENS lookup
      return ethers.isAddress(name) ? name : null;
    };

    const originalResolveNameDest = this.destProvider.resolveName.bind(
      this.destProvider
    );
    this.destProvider.resolveName = async (name: string) => {
      // If it's an address, return as-is, otherwise return null to prevent ENS lookup
      return ethers.isAddress(name) ? name : null;
    };

    // Initialize wallets
    this.sourceWallet = new ethers.Wallet(PRIVATE_KEY, this.sourceProvider);
    this.destWallet = new ethers.Wallet(PRIVATE_KEY, this.destProvider);

    // Initialize contracts
    this.sourceBridge = new ethers.Contract(
      SOURCE_BRIDGE,
      SOURCE_BRIDGE_ABI,
      this.sourceProvider
    );
    this.destBridge = new ethers.Contract(
      DEST_BRIDGE,
      DEST_BRIDGE_ABI,
      this.destWallet
    );

    logger.info("🚀 Starting ZK NFT Bridge Relayer...");
    logger.info(`Source Chain: ${SOURCE_RPC}`);
    logger.info(`Destination Chain: ${DEST_RPC}`);
    logger.info(`Source Bridge: ${SOURCE_BRIDGE}`);
    logger.info(`Destination Bridge: ${DEST_BRIDGE}`);
  }

  async start() {
    if (this.isRunning) {
      logger.warn("Relayer is already running");
      return;
    }

    this.isRunning = true;
    logger.info("✅ Relayer started successfully");

    // Start polling for events
    this.pollForEvents();
  }

  private async pollForEvents() {
    while (this.isRunning) {
      try {
        await this.processEvents();
        await this.sleep(POLL_INTERVAL);
      } catch (error) {
        logger.error("Error in polling loop:", error);
        await this.sleep(POLL_INTERVAL);
      }
    }
  }

  private async processEvents() {
    try {
      // Get the latest block number
      const latestBlock = await this.sourceProvider.getBlockNumber();
      const fromBlock = Math.max(0, latestBlock - 100); // Check last 100 blocks

      // Listen for NFTLocked events
      const lockFilter = this.sourceBridge.filters.NFTLocked();
      const lockEvents = await this.sourceBridge.queryFilter(
        lockFilter,
        fromBlock,
        latestBlock
      );

      // Listen for BatchLocked events
      const batchFilter = this.sourceBridge.filters.BatchLocked();
      const batchEvents = await this.sourceBridge.queryFilter(
        batchFilter,
        fromBlock,
        latestBlock
      );

      // Process individual NFT locks
      for (const event of lockEvents) {
        if ("args" in event) {
          await this.processSingleLock(event as unknown as NFTLockedEvent);
        }
      }

      // Process batch locks
      for (const event of batchEvents) {
        if ("args" in event) {
          await this.processBatchLock(event as unknown as BatchLockedEvent);
        }
      }
    } catch (error) {
      logger.error("Error processing events:", error);
    }
  }

  private async processSingleLock(event: NFTLockedEvent) {
    try {
      const {
        bridgeId,
        nftContract,
        tokenId,
        owner,
        destinationChainId,
        timestamp,
      } = event.args;

      // Check if already minted
      const isMinted = await this.destBridge.isMinted(bridgeId);
      if (isMinted) {
        logger.debug(`Bridge ID ${bridgeId} already minted, skipping`);
        return;
      }

      logger.info(
        `🔒 Processing single lock: Bridge ID ${bridgeId}, Token ID ${tokenId}`
      );

      // Generate mock ZK proof
      const zkProof = MOCK_ZK_PROOF;

      // Mint wrapped NFT on destination chain
      const tx = await this.destBridge.mintWrappedNFT(
        owner,
        nftContract,
        tokenId,
        bridgeId,
        zkProof
      );

      const receipt = await tx.wait();
      logger.info(
        `✅ Minted wrapped NFT: Bridge ID ${bridgeId}, TX: ${receipt.hash}`
      );
    } catch (error) {
      logger.error(
        `Error processing single lock ${event.args.bridgeId}:`,
        error
      );
    }
  }

  private async processBatchLock(event: BatchLockedEvent) {
    try {
      const { bridgeIds, merkleRoot, count } = event.args;

      logger.info(
        `🌳 Processing batch lock: ${count} NFTs, Merkle Root: ${merkleRoot}`
      );

      // For batch processing, we need to get the individual lock events
      // and process them as a batch
      const recipients: string[] = [];
      const originalContracts: string[] = [];
      const originalTokenIds: bigint[] = [];
      const validBridgeIds: string[] = [];

      // Get individual lock events for this batch
      for (const bridgeId of bridgeIds) {
        const lockFilter = this.sourceBridge.filters.NFTLocked(bridgeId);
        const lockEvents = await this.sourceBridge.queryFilter(
          lockFilter,
          -1000,
          "latest"
        );

        if (lockEvents.length > 0) {
          const lockEvent = lockEvents[0];
          if ("args" in lockEvent) {
            const { owner, nftContract, tokenId } = (
              lockEvent as unknown as NFTLockedEvent
            ).args;

            // Check if already minted
            const isMinted = await this.destBridge.isMinted(bridgeId);
            if (!isMinted) {
              recipients.push(owner);
              originalContracts.push(nftContract);
              originalTokenIds.push(tokenId);
              validBridgeIds.push(bridgeId);
            }
          }
        }
      }

      if (validBridgeIds.length === 0) {
        logger.info("All NFTs in batch already minted, skipping");
        return;
      }

      // Generate mock ZK proof
      const zkProof = MOCK_ZK_PROOF;

      // Batch mint wrapped NFTs
      const tx = await this.destBridge.batchMintWrappedNFTs(
        recipients,
        originalContracts,
        originalTokenIds,
        validBridgeIds,
        merkleRoot,
        zkProof
      );

      const receipt = await tx.wait();
      logger.info(
        `✅ Batch minted ${validBridgeIds.length} wrapped NFTs: TX: ${receipt.hash}`
      );
    } catch (error) {
      logger.error(`Error processing batch lock:`, error);
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async stop() {
    this.isRunning = false;
    logger.info("🛑 Relayer stopped");
  }
}

// Start the relayer
const relayer = new RelayerService();

// Handle graceful shutdown
process.on("SIGINT", async () => {
  logger.info("Received SIGINT, shutting down gracefully...");
  await relayer.stop();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  logger.info("Received SIGTERM, shutting down gracefully...");
  await relayer.stop();
  process.exit(0);
});

// Start the relayer
relayer.start().catch((error) => {
  logger.error("Failed to start relayer:", error);
  process.exit(1);
});
