# 🌉 ZK NFT Bridge - Complete Implementation

A cross-chain NFT bridge using zero-knowledge proofs for trustless transfers between chains.

## 📋 Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Node.js dependencies
npm install -g pnpm
```

## 🚀 Quick Start

### 1. Project Structure

```
zk-nft-bridge/
├── contracts/          # Foundry project
│   ├── src/
│   ├── script/
│   ├── test/
│   └── foundry.toml
├── relayer/           # Node.js service
│   ├── src/
│   └── package.json
└── frontend/          # Next.js app
    ├── src/
    └── package.json
```

### 2. Setup Contracts

```bash
# Create Foundry project
forge init contracts
cd contracts

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std

# Copy contract files (provided below)
# Then compile
forge build
```

### 3. Run Local Chains

```bash
# Terminal 1 - Source chain (Ethereum)
anvil --port 8545 --chain-id 1

# Terminal 2 - Destination chain (L2)
anvil --port 8546 --chain-id 421614
```

### 4. Deploy Contracts

```bash
cd contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
forge script script/Deploy.s.sol --rpc-url http://localhost:8546 --broadcast
```

### 5. Start Relayer

```bash
cd relayer
pnpm install
pnpm start
```

### 6. Start Frontend

```bash
cd frontend
pnpm install
pnpm dev
```

Visit `http://localhost:3000` to use the bridge!

## 📁 File Contents Below

Copy each file into the appropriate directory structure shown above.

---

## Key Features

✅ **Lock & Mint Mechanism** - Lock NFT on source, mint wrapped version on destination  
✅ **ZK Proof Verification** - Cryptographic ownership verification  
✅ **Merkle Batching** - Gas-efficient batch transfers  
✅ **Event Monitoring** - Automated relayer service  
✅ **Complete UI** - React interface for bridging

## Architecture

```
User → Lock NFT on Chain A → Generate ZK Proof → Relayer Monitors
  ↓
Relayer → Verify Proof → Submit to Chain B → Mint Wrapped NFT
```

## Environment Variables

Create `.env` in each directory:

**contracts/.env**

```
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
SOURCE_RPC=http://localhost:8545
DEST_RPC=http://localhost:8546
```

**relayer/.env**

```
SOURCE_RPC=http://localhost:8545
DEST_RPC=http://localhost:8546
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
SOURCE_BRIDGE=<address_from_deployment>
DEST_BRIDGE=<address_from_deployment>
```

**frontend/.env.local**

```
NEXT_PUBLIC_SOURCE_RPC=http://localhost:8545
NEXT_PUBLIC_DEST_RPC=http://localhost:8546
NEXT_PUBLIC_SOURCE_BRIDGE=<address_from_deployment>
NEXT_PUBLIC_DEST_BRIDGE=<address_from_deployment>
```

## Testing

```bash
cd contracts
forge test -vvv
```

## Resume Bullet Point

_"Developed a trustless cross-chain NFT bridge utilizing zero-knowledge proofs for cryptographic ownership verification, implementing Merkle tree batching for gas optimization and a TypeScript relayer service for automated cross-chain message passing"_
